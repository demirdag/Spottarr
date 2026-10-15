# spotsearch - search Spottarr (Newznab) and download NZBs
#   spotsearch s ["query"] [-c cat] [-s size|age] [-r] [-n N] [-a] [-o N] [-t] [-l]
#   spotsearch b <cat> [options]  browse a whole category
#   spotsearch g [n|n-m|n,m ...] [-C cat] [--local]
#                                 download (no numbers = menu on last search);
#                                 with SABNZBD_APIKEY set it goes to SABnzbd
#                                 instead of disk, in the matching category
#   spotsearch i [options]        interactive: pick categories, collect a
#                                 basket across them, send it in one go
#   spotsearch cats               list categories the server offers
#   spotsearch help               full help

function __spotsearch_base
    set -q SPOTARR_URL; and echo $SPOTARR_URL; or echo http://192.168.1.14:8383/newznab
end

function __spotsearch_sab_base
    set -q SABNZBD_URL; and echo (string trim -r -c / -- $SABNZBD_URL); or echo http://192.168.1.14:8081
end

# Newznab category ids (comma-separated) -> SABnzbd category, empty if none fits.
# Console (1xxx) and PC/Games (4050) are games; the rest of 4xxx is software.
function __spotsearch_sabcat_for
    set -l ids (string split , -- $argv[1])
    for id in $ids
        if string match -qr '^1[0-9]{3}$' -- $id; or test "$id" = 4050
            echo games
            return
        end
    end
    for id in $ids
        string match -qr '^[2-7][0-9]{3}$' -- $id; or continue
        switch (string sub -l 1 -- $id)
            case 2
                echo movies
            case 3
                echo audio
            case 4
                echo software
            case 5
                echo tv
            case 6
                echo erotica
            case 7
                echo books
        end
        return
    end
end

# upload an NZB to SABnzbd (mode=addfile): file, job name, [category], [filename]
# The key goes to curl on stdin, so it never shows up in the process list.
function __spotsearch_push
    set -l file $argv[1]
    set -l name $argv[2]
    set -l cat $argv[3]
    set -l fname $argv[4]
    test -z "$fname"; and set fname (path basename -- $file)

    set -l args -sS -m 30 -F mode=addfile -F output=json \
        -F "nzbname=$name" -F "name=@$file;filename=$fname;type=application/x-nzb"
    test -n "$cat"; and set -a args -F "cat=$cat"

    set -l resp (printf 'form = "apikey=%s"\n' $SABNZBD_APIKEY \
        | curl -K - $args (__spotsearch_sab_base)/api | string collect)
    or begin
        echo "  sabnzbd: request failed ("(__spotsearch_sab_base)")" >&2
        return 1
    end

    if string match -qr '"status":\s*true' -- $resp
        set -l id (string match -r '"nzo_ids":\s*\[\s*"([^"]+)"' -- $resp)[2]
        set -l msg "  sent to sabnzbd"
        test -n "$cat"; and set msg "$msg [$cat]"
        test -n "$id"; and set msg "$msg: $id"
        echo $msg
        return 0
    end
    set -l err (string match -r '"error":\s*"([^"]*)"' -- $resp)[2]
    test -z "$err"; and set err (string sub -l 200 -- $resp)
    echo "  sabnzbd refused it: $err" >&2
    return 1
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

# cache columns: 1 num, 2 epoch, 3 size, 4 day, 5 title, 6 url, 7 newznab cats (a,b)
# prints the human-readable list (also used as the menu input)
#   __spotsearch_fmt [file] [basket]   default file is the last search; with a
#   basket file, rows already in it are marked with *
function __spotsearch_fmt
    set -l file (__spotsearch_cache)
    set -q argv[1]; and set file $argv[1]
    set -l basket
    set -q argv[2]; and test -s "$argv[2]"; and set basket $argv[2]
    awk -F'\t' -v mark=(count $basket) '
        function h(b) { if (b >= 1073741824) return sprintf("%.2f GB", b/1073741824); return sprintf("%.0f MB", b/1048576) }
        mark && FILENAME == ARGV[1] { inb[$5] = 1; next }
        mark { printf "%3d %s %s  %9s  %s\n", $1, ($6 in inb ? "*" : " "), $4, h($3), $5; next }
        { printf "%3d  %s  %9s  %s\n", $1, $4, h($3), $5 }' $basket $file
end

# fzf menu over the last search; downloads whatever you pick
# (any arguments are options handed on to __spotsearch_get, e.g. -C tv)
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

    # select-all acts on what is visible, so type to filter, then Ctrl-A
    set -l picks (__spotsearch_fmt | fzf --multi --reverse --no-sort --height=80% \
        --prompt='nzb> ' \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
        --header='↑/↓ move   Tab mark/unmark   Ctrl-A mark all shown   Ctrl-D unmark all
Enter download marked (or highlighted)   Esc cancel   type to filter')
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
    __spotsearch_get $argv $nums
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

        if command grep -q '<error' $tmp
            echo "API error: "(command grep -o '<error[^>]*>' $tmp) >&2
            rm -f $tmp $raw
            return 1
        end

        set -l n (xmllint --xpath 'count(//item)' $tmp 2>/dev/null | string replace -r '\..*' '')
        test -z "$n"; and set n 0
        set total (xmllint --xpath "string(//*[local-name()='response']/@total)" $tmp 2>/dev/null)
        test $n -eq 0; and break

        # raw row: epoch, size, day, title, url, cats
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
            set -l cats (xmllint --xpath "//item[$i]/category" $tmp 2>/dev/null \
                | string match -rag '<category>([0-9]+)</category>' | string join ,)
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' $epoch "$size" $day "$title" "$url" "$cats" >>$raw
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

# fetch NZBs by result number. With SABNZBD_APIKEY set (and no --local) each
# one goes to SABnzbd and is only saved to disk if SABnzbd does not take it;
# otherwise it is saved. No numbers = open the menu.
function __spotsearch_get
    # --from: read results from another file in cache format (used by the basket)
    argparse 'C/sabcat=' L/local 'F/from=' -- $argv
    or return 1

    set -l cache (__spotsearch_cache)
    set -q _flag_from; and set cache $_flag_from
    if not test -s $cache
        echo "no previous search" >&2
        return 1
    end

    # no numbers: pick from the menu, keeping the options given here
    if test (count $argv) -lt 1
        set -l fwd
        set -q _flag_sabcat; and set -a fwd -C $_flag_sabcat
        set -q _flag_local; and set -a fwd --local
        __spotsearch_menu $fwd
        return
    end
    # numbers, ranges and comma lists: 3   1-5   1,4,7-9   (each picked once)
    set -l nums
    for spec in (string split , -- $argv)
        test -z "$spec"; and continue
        set -l r (string match -r '^([0-9]+)(?:-([0-9]+))?$' -- $spec)
        if test (count $r) -eq 0
            echo "not a result number or range: $spec (usage: spotsearch g 3 5 | 1-5 | 1,4,7-9 [-C cat] [--local])" >&2
            return 1
        end
        set -l range $r[2]
        if test -n "$r[3]"
            if test $r[3] -lt $r[2]
                echo "backwards range: $spec" >&2
                return 1
            end
            set range (seq $r[2] $r[3])
        end
        for n in $range
            contains -- $n $nums; or set -a nums $n
        end
    end
    __spotsearch_key_ok; or return 1

    set -l push 0
    if not set -q _flag_local; and set -q SABNZBD_APIKEY
        set push 1
    end
    set -l outdir $PWD
    set -q SPOTARR_NZB_DIR; and set outdir $SPOTARR_NZB_DIR

    set -l sent 0
    set -l saved 0
    set -l failed 0
    for n in $nums
        set -l line (awk -F'\t' -v n=$n '$1==n' $cache)
        if test -z "$line"
            echo "#$n: not in last results" >&2
            set failed (math $failed + 1)
            continue
        end
        set -l parts (string split \t -- $line)
        set -l title $parts[5]
        set -l url $parts[6]
        set -l cats $parts[7]
        if not string match -q '*apikey=*' -- $url
            set url "$url&apikey=$SPOTARR_APIKEY"
        end
        set -l safe (string replace -ra '[^A-Za-z0-9._()-]' '_' -- $title | string sub -l 120)
        set -l out "$outdir/$safe.nzb"

        set -l tmp (mktemp --suffix=.nzb)
        if not curl -fsS -o $tmp $url; or not command grep -q '<nzb' $tmp
            echo "#$n: download failed or not a valid NZB" >&2
            rm -f $tmp
            set failed (math $failed + 1)
            continue
        end

        if test $push -eq 1
            # -C wins, then the result's own category, then SABNZBD_CAT
            set -l sabcat
            if set -q _flag_sabcat
                set sabcat $_flag_sabcat
            else
                set sabcat (__spotsearch_sabcat_for "$cats")
                test -z "$sabcat"; and set -q SABNZBD_CAT; and set sabcat $SABNZBD_CAT
            end
            echo "#$n: $title"
            if __spotsearch_push $tmp $title "$sabcat" "$safe.nzb"
                rm -f $tmp
                set sent (math $sent + 1)
                continue
            end
            echo "  keeping it on disk instead" >&2
        end

        mkdir -p $outdir
        if mv -f $tmp $out
            echo "saved: $out"
            set saved (math $saved + 1)
        else
            echo "#$n: could not write $out" >&2
            rm -f $tmp
            set failed (math $failed + 1)
        end
    end

    if test (count $nums) -gt 1
        set -l summary
        test $sent -gt 0; and set -a summary "$sent sent to sabnzbd"
        test $saved -gt 0; and set -a summary "$saved saved to disk"
        test $failed -gt 0; and set -a summary "$failed failed"
        echo "-- "(count $nums)" picked: "(string join ', ' $summary)
    end
    test $failed -eq 0
end

# the server's category tree (t=caps) as rows: kind<TAB>id<TAB>name,
# kind being 'category' (top level) or 'subcat'
function __spotsearch_caprows
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

    for i in (seq $n)
        set -l row (xmllint --xpath "concat(name((//categories//*[@id])[$i]),'|',(//categories//*[@id])[$i]/@id,'|',(//categories//*[@id])[$i]/@name)" $tmp)
        string split '|' -- $row | string join \t
    end
    rm -f $tmp
end

# category tree from the server's t=caps response
function __spotsearch_cats
    set -l rows (__spotsearch_caprows)
    or return 1

    printf '%-6s %s\n' ID NAME
    for row in $rows
        set -l f (string split \t -- $row)
        if test "$f[1]" = subcat
            printf '  %-6s %s\n' $f[2] $f[3]
        else
            printf '%-6s %s\n' $f[2] $f[3]
        end
    end
    echo
    echo "use with: spotsearch s \"query\" -c <id>[,<id>...]   or   spotsearch b <id|name>"
    echo "(a parent id also matches its subcategories)"
end

# ---------- interactive mode: browse categories, collect a basket, send ----------
# The basket lives next to the search cache, one row per pick, in cache format
# without the number column (epoch, size, day, title, url, cats). It survives
# quitting, so 'spotsearch i' carries on where you left off.

function __spotsearch_basket
    echo (path dirname (__spotsearch_cache))/spotsearch.basket
end

function __spotsearch_basket_count
    set -l basket (__spotsearch_basket)
    test -s $basket; and count <$basket; or echo 0
end

# basket rows numbered 1..N into a temp file (cache format); prints its path
function __spotsearch_basket_numbered
    set -l tmp (mktemp)
    awk -F'\t' -v OFS='\t' '{ print NR, $0 }' (__spotsearch_basket) >$tmp
    echo $tmp
end

# add result numbers from a cache-format file; the url is the identity, so a
# spot already in the basket is not added twice. Prints how many were added.
function __spotsearch_basket_add
    set -l from $argv[1]
    set -l basket (__spotsearch_basket)
    touch $basket
    set -l tmp (mktemp)
    awk -F'\t' -v nums="$argv[2..-1]" '
        BEGIN { split(nums, a, " "); for (i in a) want[a[i]] = 1 }
        FILENAME == ARGV[1] { have[$5] = 1; next }
        ($1 in want) && !($6 in have) { have[$6] = 1; print substr($0, index($0, "\t") + 1) }
    ' $basket $from >$tmp
    count <$tmp
    command cat $tmp >>$basket
    rm -f $tmp
end

# show the basket; whatever is picked here is removed from it
function __spotsearch_basket_edit
    set -l n (__spotsearch_basket_count)
    if test $n -eq 0
        echo "the basket is empty"
        return 0
    end
    set -l tmp (__spotsearch_basket_numbered)
    set -l picks (__spotsearch_fmt $tmp | fzf --multi --reverse --no-sort --height=80% \
        --prompt='remove> ' \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
        --header="basket: $n   Tab mark   Ctrl-A mark all shown   Enter REMOVE marked (or highlighted)
Esc back without removing   type to filter")
    if test (count $picks) -eq 0
        rm -f $tmp
        return 0
    end
    set -l nums
    for p in $picks
        set -a nums (string replace -r '^\s*(\d+).*' '$1' -- $p)
    end
    set -l basket (__spotsearch_basket)
    awk -F'\t' -v nums="$nums" '
        BEGIN { split(nums, a, " "); for (i in a) drop[a[i]] = 1 }
        !($1 in drop) { print substr($0, index($0, "\t") + 1) }
    ' $tmp >$basket
    rm -f $tmp
    echo "removed "(count $nums)" (basket: "(__spotsearch_basket_count)")"
end

# send everything in the basket; options go on to __spotsearch_get (-C, --local).
# Whatever fails to download stays in the basket for another try.
function __spotsearch_basket_send
    set -l n (__spotsearch_basket_count)
    if test $n -eq 0
        echo "the basket is empty"
        return 0
    end
    set -l tmp (__spotsearch_basket_numbered)
    set -l keep
    for i in (seq $n)
        __spotsearch_get $argv --from $tmp $i; or set -a keep $i
    end
    set -l basket (__spotsearch_basket)
    awk -F'\t' -v nums="$keep" '
        BEGIN { split(nums, a, " "); for (i in a) keep[a[i]] = 1 }
        ($1 in keep) { print substr($0, index($0, "\t") + 1) }
    ' $tmp >$basket
    rm -f $tmp
    if test (count $keep) -gt 0
        echo "-- "(math $n - (count $keep))" of $n done; "(count $keep)" left in the basket (failed to download)"
    else
        echo "-- all $n done, basket emptied"
    end
end

# ---- spots per category, so the menu can hide empty ones ----
# Kept in spotsearch.counts (id<TAB>total) next to the search cache and
# refreshed when older than SPOTARR_COUNT_TTL hours (default 12).

function __spotsearch_counts_file
    echo (path dirname (__spotsearch_cache))/spotsearch.counts
end

# how long ago the counts were taken, e.g. 5m or 3h
function __spotsearch_counts_age
    set -l file (__spotsearch_counts_file)
    if not test -e $file
        echo never
        return
    end
    set -l s (path mtime --relative $file)
    if test $s -lt 3600
        echo (math -s0 $s / 60)m
    else
        echo (math -s0 $s / 3600)h
    end
end

#   __spotsearch_counts_refresh [-f] <cat id> ...   (-f: recount even if fresh)
function __spotsearch_counts_refresh
    argparse f/force -- $argv
    or return 1
    set -l file (__spotsearch_counts_file)
    set -l ttl 12
    set -q SPOTARR_COUNT_TTL; and set ttl $SPOTARR_COUNT_TTL
    if not set -q _flag_force; and test -s $file
        test (path mtime --relative $file) -lt (math "$ttl * 3600"); and return 0
    end

    echo "counting spots in "(count $argv)" categories ..." >&2
    set -l dir (mktemp -d)
    set -l base (__spotsearch_base)
    # one limit=1 search per category, 8 at a time; only the total is used
    printf '%s\n' $argv | xargs -P 8 -I '{}' curl -fsS -m 30 -o "$dir/{}" -G "$base/api" \
        --data-urlencode t=search --data-urlencode 'cat={}' --data-urlencode limit=1 \
        --data-urlencode "apikey=$SPOTARR_APIKEY" 2>/dev/null

    set -l out (mktemp)
    set -l failed 0
    for id in $argv
        set -l t
        test -s $dir/$id; and set t (string match -rg 'total="([0-9]+)"' <$dir/$id)[1]
        if test -n "$t"
            printf '%s\t%s\n' $id $t >>$out
        else
            set failed (math $failed + 1)
        end
    end
    rm -rf $dir
    test $failed -gt 0; and echo "  could not count $failed categories, they stay visible" >&2
    if test -s $out
        mv -f $out $file
    else
        rm -f $out
    end
end

# menu lines action<TAB>id<TAB>label from caps rows: empty categories left out,
# the others labelled with their count. Uncounted ones are shown without one.
function __spotsearch_catlines
    set -l cids
    set -l cnts
    set -l file (__spotsearch_counts_file)
    if test -s $file
        for line in (command cat $file)
            set -l f (string split \t -- $line)
            set -a cids $f[1]
            set -a cnts $f[2]
        end
    end

    set -l parent
    for row in $argv
        set -l f (string split \t -- $row)
        test "$f[2]" = 0; and continue # 'Reserved'
        set -l label $f[3]
        if test "$f[1]" = subcat
            set label "$parent / $f[3]"
        else
            set parent $f[3]
        end
        set -l i (contains -i -- $f[2] $cids)
        if test -n "$i"
            test $cnts[$i] -eq 0; and continue
            set label "$label  ("(string replace -ra '(\d)(?=(\d{3})+$)' '$1,' -- $cnts[$i])")"
        end
        printf 'cat\t%s\t%-6s %s\n' $f[2] $f[2] $label
    end
end

# quote one argument for sh
function __spotsearch_shq
    printf "'%s'" (string replace -a "'" "'\\''" -- $argv[1])
end

# fzf's Ctrl-S: search one category on the server, print the list for fzf
#   __spotsearch_reload <cat id> <query> [search options...]
#
# The result list shows one page (-n entries) at a time. Where we are is kept in
# spotsearch.page, one value per line: id, label, query, offset, limit, total,
# then the search options. fzf's keys call __spotsearch_page through sh + fish.

function __spotsearch_page_file
    echo (path dirname (__spotsearch_cache))/spotsearch.page
end

# fetch one page into the search cache and remember where we are
#   __spotsearch_page_load <cat id> <label> <query> <offset> [search options...]
function __spotsearch_page_load
    set -l id $argv[1]
    set -l label $argv[2]
    set -l query $argv[3]
    set -l offset $argv[4]
    set -e argv[1..4]
    set -l opts $argv

    set -l limit 50
    set -q SPOTARR_LIMIT; and set limit $SPOTARR_LIMIT
    set -l i (contains -i -- -n $opts); and set limit $opts[(math $i + 1)]

    set -l q
    test -n "$query"; and set q $query
    # keep stderr (it carries "fetched N of TOTAL"), drop the printed list
    set -l msg (__spotsearch_search $q -c $id -o $offset -l $opts 2>&1 >/dev/null)
    set -l st $status
    test $st -ne 0; and printf '%s\n' $msg >&2

    set -l cache (__spotsearch_cache)
    set -l got 0
    test -s $cache; and set got (count <$cache)
    set -l total (string match -rg 'of (\d+) matches' -- $msg)[1]
    test -z "$total"; and set total (math $offset + $got)

    set -l pagefile (__spotsearch_page_file)
    printf '%s\n' $id $label $query $offset $limit $total $opts >$pagefile
    return $st
end

#   __spotsearch_page list | prompt | next <selfile> | prev <selfile> | search <selfile> <query>
# next/prev/search first put whatever is marked (fzf's {+f} file) into the
# basket, because fzf forgets marks when the list reloads.
function __spotsearch_page
    set -l s (command cat (__spotsearch_page_file))
    set -l id $s[1]
    set -l label $s[2]
    set -l query $s[3]
    set -l offset $s[4]
    set -l limit $s[5]
    set -l total $s[6]
    set -l opts
    test (count $s) -ge 7; and set opts $s[7..-1]
    set -l cache (__spotsearch_cache)

    switch $argv[1]
        case list
            test -s $cache; and __spotsearch_fmt $cache (__spotsearch_basket)
            return 0
        case prompt
            set -l p "$label"
            test -n "$query"; and set p "$p [$query]"
            if test $total -gt 0
                set p "$p p"(math -s0 "$offset / $limit + 1")"/"(math -s0 "($total + $limit - 1) / $limit")
            else
                set p "$p (no matches)"
            end
            echo "$p · basket "(__spotsearch_basket_count)"> "
            return 0
    end

    # commit marks before the list changes
    if test -n "$argv[2]"; and test "$FZF_SELECT_COUNT" -gt 0 2>/dev/null
        set -l nums
        for line in (command cat $argv[2])
            set -a nums (string replace -r '^\s*(\d+).*' '$1' -- $line)
        end
        test (count $nums) -gt 0; and __spotsearch_basket_add $cache $nums >/dev/null
    end

    switch $argv[1]
        case next
            test (math $offset + $limit) -lt $total; or return 0
            __spotsearch_page_load $id $label $query (math $offset + $limit) $opts
        case prev
            test $offset -gt 0; or return 0
            set -l o (math $offset - $limit)
            test $o -lt 0; and set o 0
            __spotsearch_page_load $id $label $query $o $opts
        case search
            __spotsearch_page_load $id $label "$argv[3]" 0 $opts
    end
end

function __spotsearch_interactive
    argparse 's/sort=' 'n/limit=' r/reverse a/all t/title 'C/sabcat=' L/local -- $argv
    or return 1
    __spotsearch_key_ok; or return 1
    if not type -q fzf
        echo "interactive mode needs fzf (paru -S fzf)" >&2
        return 1
    end

    # options for each search, and for sending
    set -l searchopts
    set -q _flag_sort; and set -a searchopts -s $_flag_sort
    set -q _flag_limit; and set -a searchopts -n $_flag_limit
    set -q _flag_reverse; and set -a searchopts -r
    set -q _flag_all; and set -a searchopts -a
    set -q _flag_title; and set -a searchopts -t
    set -l getopts
    set -q _flag_sabcat; and set -a getopts -C $_flag_sabcat
    set -q _flag_local; and set -a getopts --local

    set -l rows (__spotsearch_caprows)
    or return 1
    set -l ids
    for row in $rows
        set -a ids (string split \t -- $row)[2]
    end
    __spotsearch_counts_refresh $ids
    set -l catlines (__spotsearch_catlines $rows)

    set -l cache (__spotsearch_cache)
    set -l basket (__spotsearch_basket)
    set -l sendto SABnzbd
    if set -q _flag_local; or not set -q SABNZBD_APIKEY
        set sendto disk
    end

    while true
        set -l n (__spotsearch_basket_count)
        set -l actions
        if test $n -gt 0
            set -a actions "send\t-\t>> send the basket ($n) to $sendto"
            set -a actions "edit\t-\t>> view / edit the basket ($n)"
            set -a actions "clear\t-\t>> empty the basket"
        end
        set -a actions "recount\t-\t>> recount categories (counted "(__spotsearch_counts_age)" ago)"
        set -a actions "quit\t-\t>> quit"

        set -l choice (begin; printf '%b\n' $actions; printf '%s\n' $catlines; end \
            | fzf --reverse --no-sort --height=80% --delimiter='\t' --with-nth=3 \
                --prompt='category> ' \
                --header="basket: $n   Enter pick a category or action   Esc quit   type to filter
empty categories are hidden; (n) = spots in it")
        or break
        set -l f (string split \t -- $choice)

        switch $f[1]
            case quit
                break
            case recount
                __spotsearch_counts_refresh -f $ids
                set catlines (__spotsearch_catlines $rows)
            case send
                __spotsearch_basket_send $getopts
            case edit
                __spotsearch_basket_edit
            case clear
                read -l -P "empty the basket ($n)? [y/N] " yn
                if string match -qi 'y*' -- "$yn"
                    : >$basket
                    echo "basket emptied"
                end
            case cat
                set -l id $f[2]
                set -l label (string replace -r '^\S+\s+' '' -- $f[3] | string replace -r '\s+\([0-9,]+\)$' '' | string trim)

                # open on the newest page straight away
                __spotsearch_page_load $id $label '' 0 $searchopts
                or continue
                if not test -s $cache
                    echo "nothing in $label"
                    continue
                end

                # Typing filters the page locally. Ctrl-F/Ctrl-B page through the
                # category, Ctrl-S searches all of it for the typed text. Those
                # run through sh (fzf) and call back into this file via fish.
                set -l F "fish --no-config -c "(__spotsearch_shq "source "(string escape -- (functions --details spotsearch))"; __spotsearch_page \$argv")" --"
                set -l show "+deselect-all+reload($F list)+transform-prompt($F prompt)"
                set -l before (__spotsearch_basket_count)

                set -l picks (__spotsearch_page list | fzf --multi --reverse --no-sort --height=80% \
                    --with-shell 'sh -c' \
                    --prompt=(__spotsearch_page prompt) \
                    --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
                    --bind 'result:first' \
                    --bind "ctrl-f:execute-silent($F next {+f})$show" \
                    --bind "ctrl-b:execute-silent($F prev {+f})$show" \
                    --bind "ctrl-s:execute-silent($F search {+f} {q})$show+clear-query" \
                    --header="Tab mark   Ctrl-A mark all shown   Ctrl-D unmark all   * = in basket
Ctrl-F next page   Ctrl-B previous page   typing filters this page
Ctrl-S search all of $label for what you typed (empty: newest again)
Enter add marked (or highlighted) to the basket   Esc back
(marks also go into the basket when you change page or search)")

                set -l nums
                for p in $picks
                    set -a nums (string replace -r '^\s*(\d+).*' '$1' -- $p)
                end
                test (count $nums) -gt 0; and __spotsearch_basket_add $cache $nums >/dev/null
                set -l added (math (__spotsearch_basket_count) - $before)
                if test $added -gt 0
                    echo "added $added to the basket, basket: "(__spotsearch_basket_count)
                else if test (count $nums) -gt 0
                    echo "already in the basket"
                end
        end
    end

    set -l n (__spotsearch_basket_count)
    if test $n -gt 0
        echo "basket kept with $n item(s): 'spotsearch i' to carry on or send it"
    end
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
    set -l sabkey "not set (NZBs are only saved)"
    set -q SABNZBD_APIKEY; and set sabkey "set (downloads are sent to SABnzbd)"
    set -l saburl (__spotsearch_sab_base)
    set -l sabcat "not set (SABnzbd's default)"
    set -q SABNZBD_CAT; and set sabcat $SABNZBD_CAT
    set -l fz "NOT INSTALLED (paru -S fzf)"
    type -q fzf; and set fz installed

    echo "spotsearch - search Spottarr (Newznab) and download NZBs

USAGE
  spotsearch s [\"query\"] [options]   search; opens a menu to pick NZBs
                                     (query is optional if you give -c)
  spotsearch b <cat> [options]       browse a whole category, no query needed
  spotsearch g [n ...] [options]     download result number(s) from the last
                                     search: 3 5, ranges 1-5, lists 1,4,7-9;
                                     with no numbers, reopens the menu
  spotsearch i [options]             interactive: pick a category, mark
                                     results, go to the next category, mark
                                     more, then send the whole basket
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

OPTIONS (for g, and for the menu that s / b / g open)
  -C, --sabcat <cat>   SABnzbd category for this download (overrides the
                       automatic one)
  -L, --local          only save the NZB, do not send it to SABnzbd

  When SABNZBD_APIKEY is set, NZBs go straight to SABnzbd and nothing is
  written to disk. An NZB is only saved to SPOTARR_NZB_DIR when SABnzbd
  refuses it or cannot be reached, with --local, or without a key.

  The SABnzbd category follows the result's category:
    1000 console, 4050 pc games  -> games      2000 movies  -> movies
    3000 audio                   -> audio      4000 pc/apps -> software
    5000 tv                      -> tv         6000 xxx     -> erotica
    7000 books                   -> books
  Anything else (8000 other) gets SABNZBD_CAT, or SABnzbd's default if
  that is not set either.

  The menu that opens after s / b always uses the defaults; to pick a
  category or stay local from the menu, use: spotsearch g -C <cat>   or
  spotsearch g --local

MENU KEYS (needs fzf)
  Up / Down     move
  Tab           mark / unmark an entry (pick several)
  Ctrl-A        mark every entry currently shown (filter first to narrow it)
  Ctrl-D        unmark everything
  Enter         download the marked entries (or the highlighted one)
  Esc, Ctrl-C   cancel
  (typing)      filter the list by title

  The menu opens when output goes to a terminal. When piped (| grep ...) or
  with -l you get the plain numbered list instead.

INTERACTIVE MODE (spotsearch i, needs fzf)
  1. Pick a category (type to filter, e.g. 'games' or 'uhd'). Empty
     categories are hidden and the rest show how many spots they hold;
     the counts are refreshed every SPOTARR_COUNT_TTL hours, or with
     '>> recount categories'. (Spottarr files every game, Switch too,
     under PC / Games, so the Console categories are always empty.)
  2. The newest page of that category opens straight away (-n entries per
     page, default $limit). The prompt shows the page, e.g. p1/42.
       Ctrl-F / Ctrl-B   next / previous page
       typing            filters the page you are on
       Ctrl-S            search the WHOLE category on the server for what
                         you typed; the matches are paged the same way.
                         Ctrl-S with nothing typed: newest again.
  3. Mark results (Tab, Ctrl-A) and press Enter: they go into the basket.
     Marks also go into the basket when you change page or search, so you
     can mark on several pages. Esc goes back (marks on the page you are
     on are not added). Results already in the basket show a *.
  4. Back at the category list, pick another category and repeat.
  5. At the top of the category list:
       >> send the basket     download everything and send it to SABnzbd
       >> view / edit         mark entries and Enter to remove them
       >> empty the basket
  Esc or '>> quit' leaves; the basket is kept (~/.cache/spotsearch.basket)
  for the next 'spotsearch i'. Anything that fails to download stays in it.

  Options: -n -a -s -r -t apply to every search; -C and --local apply when
  sending (without -C each item gets its own SABnzbd category).

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
  spotsearch g 1-10                                download results 1 to 10
  spotsearch g 1-3,7,12-14 -C games                several, all as games
  spotsearch i                                     interactive basket mode
  spotsearch i -n 200 -s age                       200 newest per category
  spotsearch g 3 -C tv                             download, queue in SABnzbd as tv
  spotsearch g --local                             menu, save only (no SABnzbd)

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
  SABNZBD_APIKEY    SABnzbd API key (Config > General), currently: $sabkey
  SABNZBD_URL       currently: $saburl
  SABNZBD_CAT       category for results with no match, currently: $sabcat
  SPOTARR_COUNT_TTL hours before category counts are refreshed (default 12)

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
            set -l rest
            test (count $argv) -ge 2; and set rest $argv[2..-1]
            __spotsearch_get $rest
        case i interactive
            set -l rest
            test (count $argv) -ge 2; and set rest $argv[2..-1]
            __spotsearch_interactive $rest
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

complete -c spotsearch -f -n __fish_use_subcommand -a 's b g i cats help' -d 'search / browse / get / interactive / categories / help'
complete -c spotsearch -n '__fish_seen_subcommand_from b browse' -f -a "$__spotsearch_catnames"
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse i interactive' -s s -l sort -x -a 'size age'
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s c -l cat -x -a "$__spotsearch_catnames"
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse i interactive' -s r -l reverse
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse i interactive' -s n -l limit -x
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s o -l offset -x
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse i interactive' -s a -l all
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse i interactive' -s t -l title
complete -c spotsearch -n '__fish_seen_subcommand_from s search b browse' -s l -l list
complete -c spotsearch -n '__fish_seen_subcommand_from g get i interactive' -s C -l sabcat -x -a 'tv audio movies software erotica books games' -d 'SABnzbd category'
complete -c spotsearch -n '__fish_seen_subcommand_from g get i interactive' -s L -l local -d 'save only, do not send to SABnzbd'
