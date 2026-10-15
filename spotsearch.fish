# spotsearch - search Spottarr (Newznab) and download NZBs
#   spotsearch s ["query"] [-c cat] [-s size|age] [-r] [-n N] [-a] [-o N] [-t] [-l]
#   spotsearch b <cat> [options]  browse a whole category
#   spotsearch g [n ...]          download (no numbers = menu on last search)
#   spotsearch cats               list categories the server offers
#   spotsearch help               full help

function __spotsearch_base
    set -q SPOTARR_URL; and echo $SPOTARR_URL; or echo http://192.168.1.14:8383/newznab
end

function __spotsearch_cache
    set -q XDG_CACHE_HOME; and set -l d $XDG_CACHE_HOME; or set -l d $HOME/.cache
    mkdir -p $d
    echo $d/spotsearch.last
end

function __spotsearch_key_ok
    if not set -q SPOTARR_APIKEY
        echo "SPOTARR_APIKEY is not set (run: set -Ux SPOTARR_APIKEY 'your-key')" >&2
        return 1
    end
end

# name or id (comma-separated allowed) -> comma-separated ids
function __spotsearch_cat
    set -l out
    for c in (string split , -- $argv[1])
        switch (string lower -- $c)
            case console
                set -a out 1000
            case nds
                set -a out 1010
            case psp
                set -a out 1020
            case wii
                set -a out 1030
            case switch
                set -a out 1035
            case xbox
                set -a out 1040
            case xbox360
                set -a out 1050
            case wiiware
                set -a out 1060
            case xbox360-dlc
                set -a out 1070
            case ps3
                set -a out 1080
            case xbox-one
                set -a out 1090
            case ps4
                set -a out 1100
            case movies
                set -a out 2000
            case movies-foreign
                set -a out 2010
            case movies-other
                set -a out 2020
            case movies-sd
                set -a out 2030
            case movies-hd
                set -a out 2040
            case movies-uhd
                set -a out 2045
            case movies-bluray
                set -a out 2050
            case movies-3d
                set -a out 2060
            case audio
                set -a out 3000
            case mp3
                set -a out 3010
            case audio-video
                set -a out 3020
            case audiobook
                set -a out 3030
            case lossless
                set -a out 3040
            case podcast
                set -a out 3050
            case apps pc
                set -a out 4000
            case 0day
                set -a out 4010
            case iso
                set -a out 4020
            case mac
                set -a out 4030
            case mobile-other
                set -a out 4040
            case pc-games games
                set -a out 4050
            case ios
                set -a out 4060
            case android
                set -a out 4070
            case tv
                set -a out 5000
            case tv-foreign
                set -a out 5020
            case tv-sd
                set -a out 5030
            case tv-hd
                set -a out 5040
            case tv-uhd
                set -a out 5045
            case tv-other
                set -a out 5050
            case tv-sport
                set -a out 5060
            case tv-anime
                set -a out 5070
            case tv-doc
                set -a out 5080
            case xxx
                set -a out 6000
            case xxx-dvd
                set -a out 6010
            case xxx-wmv
                set -a out 6020
            case xxx-xvid
                set -a out 6030
            case xxx-x264
                set -a out 6040
            case xxx-pack
                set -a out 6050
            case xxx-imgset
                set -a out 6060
            case xxx-other
                set -a out 6070
            case books
                set -a out 7000
            case mags
                set -a out 7010
            case ebook
                set -a out 7020
            case comics
                set -a out 7030
            case books-other
                set -a out 7900
            case other
                set -a out 8000
            case misc
                set -a out 8010
            case custom
                set -a out 100000
            case '*'
                if string match -qr '^[0-9]+$' -- $c
                    set -a out $c
                else
                    # retry without a parent prefix: console-ps4 -> ps4, pc-iso -> iso
                    set -l lc (string lower -- $c)
                    set -l short (string replace -r '^(console|pc|apps|audio|books|other|movies|tv|xxx)-' '' -- $lc)
                    set -l sub
                    if test "$short" != "$lc"
                        set sub (__spotsearch_cat $short 2>/dev/null)
                    end
                    if test -n "$sub"
                        set -a out $sub
                    else
                        echo "unknown category: $c (try: spotsearch cats)" >&2
                        return 1
                    end
                end
        end
    end
    string join , $out
    return 0
end

# cache columns: 1 num, 2 epoch, 3 size, 4 day, 5 title, 6 url
# prints the human-readable list (also used as the menu input)
function __spotsearch_fmt
    awk -F'\t' '
        function h(b) { if (b >= 1073741824) return sprintf("%.2f GB", b/1073741824); return sprintf("%.0f MB", b/1048576) }
        { printf "%3d  %s  %9s  %s\n", $1, $4, h($3), $5 }' (__spotsearch_cache)
end

# fzf menu over the last search; downloads whatever you pick
function __spotsearch_menu
    set -l cache (__spotsearch_cache)
    if not test -s $cache
        echo "no previous search" >&2
        return 1
    end
    if not type -q fzf
        echo "fzf is not installed (paru -S fzf); use: spotsearch g <number>" >&2
        return 1
    end

    set -l picks (__spotsearch_fmt | fzf --multi --reverse --no-sort --height=80% \
        --prompt='nzb> ' \
        --header='↑/↓ move   Tab mark   Enter download   Esc cancel   (type to filter)')
    or begin
        echo cancelled
        return 0
    end
    if test (count $picks) -eq 0
        echo cancelled
        return 0
    end

    set -l nums
    for p in $picks
        set -a nums (string replace -r '^\s*(\d+).*' '$1' -- $p)
    end
    __spotsearch_get $nums
end

function __spotsearch_search
    argparse 'c/cat=' 's/sort=' 'n/limit=' 'o/offset=' r/reverse l/list t/title a/all -- $argv
    or return 1
    __spotsearch_key_ok; or return 1

    set -l query ''
    set -q argv[1]; and set query $argv[1]

    # category: -c wins, else old-style second positional arg
    set -l catspec $_flag_cat
    if test -z "$catspec"; and set -q argv[2]
        set catspec $argv[2]
    end

    if test -z "$query"; and test -z "$catspec"
        echo 'usage: spotsearch s ["query"] [-c cat] [-s size|age] [-r] [-n N] [-a] [-o N] [-t] [-l]' >&2
        echo '       (give a query, a category, or both)' >&2
        return 1
    end

    set -l category
    if test -n "$catspec"
        set category (__spotsearch_cat $catspec)
        or return 1
    end

    # sort: column numbers refer to the raw rows (1=epoch, 2=size)
    set -l sortcol
    switch "$_flag_sort"
        case ''
        case size
            set sortcol 2
        case age
            set sortcol 1
        case '*'
            echo "-s must be 'size' or 'age'" >&2
            return 1
    end
    if set -q _flag_reverse; and test -z "$sortcol"
        echo "-r needs -s size|age" >&2
        return 1
    end
    set -l order nr
    set -q _flag_reverse; and set order n

    # how many results to fetch in total, and where to start
    set -l want 50
    set -q SPOTARR_LIMIT; and set want $SPOTARR_LIMIT
    set -q _flag_limit; and set want $_flag_limit
    set -l cap 5000
    set -q SPOTARR_MAX; and set cap $SPOTARR_MAX
    set -q _flag_all; and set want $cap
    set -l start 0
    set -q _flag_offset; and set start $_flag_offset
    for v in $want $start
        if not string match -qr '^[0-9]+$' -- $v
            echo "-n and -o need whole numbers" >&2
            return 1
        end
    end
    if test $want -gt $cap
        echo "-- limit capped at $cap (raise with: set -Ux SPOTARR_MAX <number>)" >&2
        set want $cap
    end

    # -t: words that must all appear in the title
    set -l words
    if set -q _flag_title; and test -n "$query"
        set words (string lower -- $query | string replace -ra '[^[:alnum:]]+' ' ' | string trim | string split ' ' | string match -rv '^$')
    end

    set -l base (__spotsearch_base)
    set -l cache (__spotsearch_cache)

    set -l baseargs -G "$base/api" --data-urlencode t=search --data-urlencode "apikey=$SPOTARR_APIKEY"
    test -n "$query"; and set -a baseargs --data-urlencode "q=$query"
    test -n "$category"; and set -a baseargs --data-urlencode "cat=$category"

    set -l tmp (mktemp)
    set -l raw (mktemp)
    set -l offset $start
    set -l fetched 0
    set -l kept 0
    set -l dropped 0
    set -l total ''
    set -l progressed 0

    # fetch page by page (100 per request) until we have enough or run out
    while test $fetched -lt $want
        set -l page (math "min($want - $fetched, 100)")
        if not curl -fsS $baseargs --data-urlencode "limit=$page" --data-urlencode "offset=$offset" >$tmp
            echo "request failed" >&2
            rm -f $tmp $raw
            return 1
        end

        if grep -q '<error' $tmp
            echo "API error: "(grep -o '<error[^>]*>' $tmp) >&2
            rm -f $tmp $raw
            return 1
        end

        set -l n (xmllint --xpath 'count(//item)' $tmp 2>/dev/null | string replace -r '\..*' '')
        test -z "$n"; and set n 0
        set total (xmllint --xpath "string(//*[local-name()='response']/@total)" $tmp 2>/dev/null)
        test $n -eq 0; and break

        # raw row: epoch, size, day, title, url
        for i in (seq $n)
            set -l title (xmllint --xpath "string(//item[$i]/title)" $tmp)

            if test (count $words) -gt 0
                set -l norm (string lower -- $title | string replace -ra '[^[:alnum:]]+' ' ')
                set -l ok 1
                for w in $words
                    string match -q "* $w *" -- " $norm "; or set ok 0
                end
                if test $ok -eq 0
                    set dropped (math $dropped + 1)
                    continue
                end
            end

            set -l url (xmllint --xpath "string(//item[$i]/enclosure/@url)" $tmp)
            set -l size (xmllint --xpath "string(//item[$i]/enclosure/@length)" $tmp)
            set -l pub (xmllint --xpath "string(//item[$i]/pubDate)" $tmp)
            set -l epoch (date -d "$pub" +%s 2>/dev/null)
            or set epoch 0
            set -l day (date -d "@$epoch" +%F 2>/dev/null)
            or set day '?'
            printf '%s\t%s\t%s\t%s\t%s\n' $epoch "$size" $day "$title" "$url" >>$raw
            set kept (math $kept + 1)
        end

        set fetched (math $fetched + $n)
        set offset (math $offset + $n)

        if test -n "$total"; and test $offset -ge $total
            break
        end
        if test $want -gt 100; and isatty stderr
            printf '\r-- fetched %s of %s ...' $fetched $want >&2
            set progressed 1
        end
    end
    test $progressed -eq 1; and printf '\r\033[K' >&2

    : >$cache
    if test $fetched -eq 0
        echo "no results"
        rm -f $tmp $raw
        return 0
    end
    if test $kept -eq 0
        echo "no results ($dropped of $fetched dropped by -t: title must contain every query word)"
        rm -f $tmp $raw
        return 0
    end

    if test -n "$sortcol"
        sort -t \t -k"$sortcol,$sortcol$order" $raw | awk -F'\t' -v OFS='\t' '{print NR, $0}' >$cache
    else
        awk -F'\t' -v OFS='\t' '{print NR, $0}' $raw >$cache
    end
    rm -f $tmp $raw

    if test $dropped -gt 0
        echo "-- -t hid $dropped of $fetched results (title lacked a query word)" >&2
    end
    if test -n "$total"; and test (math "$start + $fetched") -lt "$total" 2>/dev/null
        echo "-- fetched $fetched of $total matches (from offset $start). More: -n <num>, -a for all, -o <offset> to page." >&2
    end

    # menu on a terminal (if fzf exists), plain list otherwise or with -l
    if not set -q _flag_list; and isatty stdout; and type -q fzf
        __spotsearch_menu
    else
        __spotsearch_fmt
        if not set -q _flag_list; and isatty stdout
            echo "-- install fzf for the arrow-key menu (paru -S fzf)" >&2
        end
    end
end

function __spotsearch_get
    set -l cache (__spotsearch_cache)
    if not test -s $cache
        echo "no previous search" >&2
        return 1
    end
    if test (count $argv) -lt 1
        echo "usage: spotsearch g <number> [number ...]" >&2
        return 1
    end
    __spotsearch_key_ok; or return 1

    set -l outdir $PWD
    set -q SPOTARR_NZB_DIR; and set outdir $SPOTARR_NZB_DIR
    mkdir -p $outdir

    for n in $argv
        set -l line (awk -F'\t' -v n=$n '$1==n' $cache)
        if test -z "$line"
            echo "#$n: not in last results" >&2
            continue
        end
        set -l parts (string split \t -- $line)
        set -l title $parts[5]
        set -l url $parts[6]
        if not string match -q '*apikey=*' -- $url
            set url "$url&apikey=$SPOTARR_APIKEY"
        end
        set -l safe (string replace -ra '[^A-Za-z0-9._()-]' '_' -- $title | string sub -l 120)
        set -l out "$outdir/$safe.nzb"

        if curl -fsS -o $out $url; and grep -q '<nzb' $out
            echo "saved: $out"
        else
            echo "#$n: download failed or not a valid NZB ($out)" >&2
        end
    end
end

# category tree from the server's t=caps response
function __spotsearch_cats
    __spotsearch_key_ok; or return 1
    set -l tmp (mktemp)
    set -l base (__spotsearch_base)
    curl -fsS -G "$base/api" --data-urlencode t=caps --data-urlencode "apikey=$SPOTARR_APIKEY" >$tmp
    or begin
        echo "request failed" >&2
        rm -f $tmp
        return 1
    end

    set -l n (xmllint --xpath 'count(//categories//*[@id])' $tmp 2>/dev/null | string replace -r '\..*' '')
    if test -z "$n"; or test "$n" -eq 0
        echo "no categories found in the caps response" >&2
        rm -f $tmp
        return 1
    end

    printf '%-6s %s\n' ID NAME
    for i in (seq $n)
        set -l row (xmllint --xpath "concat(name((//categories//*[@id])[$i]),'|',(//categories//*[@id])[$i]/@id,'|',(//categories//*[@id])[$i]/@name)" $tmp)
        set -l f (string split '|' -- $row)
        if test "$f[1]" = subcat
            printf '  %-6s %s\n' $f[2] $f[3]
        else
            printf '%-6s %s\n' $f[2] $f[3]
        end
    end
    rm -f $tmp
    echo
    echo "use with: spotsearch s \"query\" -c <id>[,<id>...]   or   spotsearch b <id|name>"
    echo "(a parent id also matches its subcategories)"
end

function __spotsearch_help
    set -l url (__spotsearch_base)
    set -l dir $PWD
    set -q SPOTARR_NZB_DIR; and set dir $SPOTARR_NZB_DIR
    set -l limit 50
    set -q SPOTARR_LIMIT; and set limit $SPOTARR_LIMIT
    set -l max 5000
    set -q SPOTARR_MAX; and set max $SPOTARR_MAX
    set -l key "NOT SET"
    set -q SPOTARR_APIKEY; and set key set
    set -l fz "NOT INSTALLED (paru -S fzf)"
    type -q fzf; and set fz installed

    echo "spotsearch - search Spottarr (Newznab) and download NZBs

USAGE
  spotsearch s [\"query\"] [options]   search; opens a menu to pick NZBs
                                     (query is optional if you give -c)
  spotsearch b <cat> [options]       browse a whole category, no query needed
  spotsearch g [n ...]               download result number(s) from the last
                                     search; with no numbers, reopens the menu
  spotsearch cats                    list the categories the server offers
  spotsearch help                    show this help

OPTIONS (for s and b)
  -c, --cat <cat>      category name or numeric ID, comma-separate for several
  -s, --sort <key>     size = biggest first, age = newest first
  -r, --reverse        flip the sort (smallest / oldest first), needs -s
  -n, --limit <num>    how many results to fetch in total (default $limit);
                       fetched in pages of 100 automatically
  -a, --all            fetch everything, up to the cap of $max
  -o, --offset <num>   start at this position (for manual paging)
  -t, --title          keep only results whose TITLE contains every query word
                       (whole words, ignores case and . - _ punctuation)
  -l, --list           print a plain numbered list instead of the menu

  The old style also works: spotsearch s \"hot fuzz\" movies

MENU KEYS (needs fzf)
  Up / Down     move
  Tab           mark / unmark an entry (pick several)
  Enter         download the marked entries (or the highlighted one)
  Esc, Ctrl-C   cancel
  (typing)      filter the list by title

  The menu opens when output goes to a terminal. When piped (| grep ...) or
  with -l you get the plain numbered list instead.

CATEGORIES
  Run 'spotsearch cats' to see exactly what your server offers. Any ID works
  (-c 2045, -c 2040,2045); a parent ID also matches its subcategories.
  Names:
  movies  movies-foreign movies-other movies-sd movies-hd movies-uhd
          movies-bluray movies-3d
  tv      tv-foreign tv-sd tv-hd tv-uhd tv-other tv-sport tv-anime tv-doc
  audio   mp3 audio-video audiobook lossless podcast
  apps (pc)  0day iso mac mobile-other pc-games (games) ios android
  console nds psp wii switch xbox xbox360 wiiware xbox360-dlc ps3 xbox-one ps4
  xxx     xxx-dvd xxx-wmv xxx-xvid xxx-x264 xxx-pack xxx-imgset xxx-other
  books   mags ebook comics books-other
  other   misc custom

EXAMPLES
  spotsearch s \"hot fuzz\"                          search, then pick from menu
  spotsearch s \"hot fuzz\" -t -c movies             titles containing hot AND fuzz
  spotsearch s \"hot fuzz\" -c movies-hd -s size     HD movies, biggest first
  spotsearch b movies-uhd                          browse everything in UHD movies
  spotsearch b movies-uhd -n 300 -s size           300 results, biggest first
  spotsearch b tv-anime -a -s age                  all anime, newest first
  spotsearch b 2000 -o 100 -n 100                  results 101-200 of Movies
  spotsearch s -c 2040,2045 -l                     list HD + UHD, no menu
  spotsearch s \"tt0425112\" -n 100 -s age           search by IMDb ID in descriptions
  spotsearch s \"matrix\" -c movies | grep -i 2160p  filtered plain list
  spotsearch g                                     reopen menu on last search
  spotsearch g 3 5 8                               download by number

NOTES
  - The query searches titles AND descriptions and matches ANY word, so
    results can be noisy. Use -t to keep only titles with every word, and -c
    to narrow by category. -t is useless for IMDb-ID searches (the ID is in
    the description, not the title) and is ignored with no query.
  - Sorting and -t only cover the fetched results. If you see 'fetched 50 of
    213 matches', raise -n or use -a. Browsing a big category with a small
    -n shows whatever the server returns first, which may not be the newest.
  - Result numbers match the list you see (after filtering and sorting). The
    last search is stored in ~/.cache/spotsearch.last and shared between
    terminals.

SETTINGS (universal variables, set once with: set -Ux NAME value)
  SPOTARR_APIKEY    required, currently: $key
  SPOTARR_URL       currently: $url
  SPOTARR_NZB_DIR   where NZBs are saved, currently: $dir
  SPOTARR_LIMIT     default result count, currently: $limit
  SPOTARR_MAX       cap for -n / -a, currently: $max

TOOLS
  fzf: $fz"
end

function spotsearch --description 'Search Spottarr and download NZBs'
    switch "$argv[1]"
        case s search
            __spotsearch_search $argv[2..-1]
        case b browse
            if test (count $argv) -lt 2
                echo "usage: spotsearch b <category> [-s size|age] [-r] [-n N] [-a] [-o N] [-l]" >&2
                return 1
            end
            set -l rest
            test (count $argv) -gt 2; and set rest $argv[3..-1]
            __spotsearch_search -c $argv[2] $rest
        case g get
            if test (count $argv) -ge 2
                __spotsearch_get $argv[2..-1]
            else
                __spotsearch_menu
            end
        case cats
            __spotsearch_cats
        case '' help -h --help
            __spotsearch_help
        case '*'
            echo "unknown command: $argv[1]" >&2
            echo >&2
            __spotsearch_help >&2
            return 1
    end
end

set -g __spotsearch_catnames movies movies-foreign movies-other movies-sd movies-hd movies-uhd movies-bluray movies-3d tv tv-foreign tv-sd tv-hd tv-uhd tv-other tv-sport tv-anime tv-doc audio mp3 audio-video audiobook lossless podcast apps pc 0day iso mac mobile-other pc-games games ios android console nds psp wii switch xbox xbox360 wiiware xbox360-dlc ps3 xbox-one ps4 xxx xxx-dvd xxx-wmv xxx-xvid xxx-x264 xxx-pack xxx-imgset xxx-other books mags ebook comics books-other other misc custom

complete -c spotsearch -f -n __fish_use_subcommand -a 's b g cats help' -d 'search / browse / get / categories / help'
complete -c spotsearch -n '__fish_seen_subcommand_from b browse' -f -a "$__spotsearch_catnames"
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s s -l sort -x -a 'size age'
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s c -l cat -x -a "$__spotsearch_catnames"
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s r -l reverse
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s n -l limit -x
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s o -l offset -x
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s a -l all
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s t -l title
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s l -l list
