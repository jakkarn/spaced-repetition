## rehearsal program for space repetition ##

rhrs_dir()  { echo "$HOME/.rehearse/"; }
today()     { echo `date +%Y-%m-%d`; }

## get the difference between two dates (end - start) ##
function rehearse-get-diff
{
    if (( $# != 2 )); then
        echo "Usage:  ${FUNCNAME[0]} <date_end> <date_start>"
    else
        t_start=$(date --date "$2" +%s)
        t_end=$(date --date "$1" +%s)
        echo $(( (t_end - t_start) / (60*60*24) ))
    fi
}

## get how many days from start-date next interval is
function rehearse-get-interval
{
    array=(0 1 4 11 25 55 115 235 560 1001 1501 3001 5001 10001)

    if (( $# != 1 )); then
        echo "Usage:  ${FUNCNAME[0]} <days>"
    else
        for i in ${!array[@]}; do  # '!' - keys of array
        days=${array[$i]}
            if (( $1 <=  days )); then
                echo ${array[$i]}
                return
            fi
        done
        echo -1
    fi
}

## get next rehearsal date from start-date
function rehearse-get-next
{
    if (( $# != 1 )); then
        echo "Usage: ${FUNCNAME[0]} <start-date>"
    else
        days=`rehearse-get-diff $(today) $1`
        days=`rehearse-get-interval $days`
        next_date=$(date "+%Y-%m-%d" -d "$1+$days days")
        echo $next_date
    fi
}


## add a new rehearsal entry for a course ##
function rehearse-add
{
    if (( $# != 2 )); then
        echo "Usage:  ${FUNCNAME[0]} <course> \"<description of content>\""
    else
        lhs="$1: $2"
        margin=$(( 55-${#lhs} ))

        # good length to print neatly
        if (( $margin > 0 )); then

            ## check if entry already exists ##
            new_entry="$(today);$1;$2"
            for path in $(rhrs_dir)*; do
                if [ -f $path ]; then
                    matches=`grep -c "$new_entry" $path`
                    if (( $matches != 0 )); then
                        echo "Don't add it again! (see ${path##*/})"
                        return 0
                    fi
                fi
            done

            ## only add if there is such a file ##
            same_lines=0
            if [ -f $(rhrs_dir)$(today) ]; then
                temp_path=`echo "$(rhrs_dir)$(today)"`
                same_lines=`grep -c "$new_entry" "$temp_path"`
            fi

            ## doesn't check correctly if rehearsal has been moved by update ##
            if (( same_lines == 0 )); then
                if [ -f $(rhrs_dir)$(today) ]; then
                    # append to existing rehearsal date
                    echo $new_entry >> `echo "$(rhrs_dir)$(today)"`
                else
                    # create new rehearsal date
                    echo $new_entry > `echo "$(rhrs_dir)$(today)"`
                fi
                #rehearse-update
                echo "added \"$1: $2\" for rehearsal"
            else
                echo "Don't add it again!"
            fi

        # too long string to print neatly
        else
            chars_left=$(( -$margin ))
            if (( $chars_left == 1 )); then
                echo "Rejected. Remove at least one of your letters."
            else
                echo "Rejected. Describe it in $chars_left letters less."
            fi
        fi
    fi
}

## run update twice, cause have everything integrated in one loop :3
function rehearse-update
{
    rehearse-update-single
    rehearse-update-single
}

## move dates to correct date, remove empty files
function rehearse-update-single
{
    for path in $(rhrs_dir)*; do

        # ignore directory-path
        if [ -f $path ]; then
            non_spaces=`grep -c '[^[:space:]]' "$path"`

            # loop-vars #
            lines=`wc -l < $path`
            line_nr=1

            # check that the file contains something #
            if (( $non_spaces > 0 )); then
                cat "$path" > `echo $(rhrs_dir)temp0` # make temporary copy
                name=${path##*/}
                # get date for each line in file #
                while read line; do
                    start_date=${line%%;*}      # remove all up to first ';'
                    new_date=`rehearse-get-next "$start_date"`
                    lines=`wc -l < $(rhrs_dir)'temp0'`
                    ## move date if updated
                    if [ $new_date != $name ]; then
                        if [ -f ~/.rehearse/$new_date ]; then
                            # append entry to existing rehearse date
                            echo $line >> `echo "$(rhrs_dir)$new_date"`
                        else
                            # create new file for rehearse date
                            echo $line > `echo "$(rhrs_dir)$new_date"`
                        fi
                        # update tempcopy without the moved line #
                        head -n $(($line_nr-1)) `echo "$(rhrs_dir)temp0"` \
                            > `echo "$(rhrs_dir)temp1"`
                        tail -n $(($lines-$line_nr)) `echo "$(rhrs_dir)temp0"` \
                            >> `echo "$(rhrs_dir)temp1"`

                        cat $(rhrs_dir)temp1 > $(rhrs_dir)temp0

                        lines=`wc -l < $(rhrs_dir)'temp0'` # removed one line
                        line_nr=$(($line_nr-1)) # removed one line
                    fi
                    line_nr=$(($line_nr+1))     # increment line-counter
                done < $path

                ## remove temp files (check if exists should be redundant)
                if [ -f $(rhrs_dir)temp0 ]; then
                    cat $(rhrs_dir)temp0 > $path # overwrite original
                    rm $(rhrs_dir)temp0
                fi
                if [ -f $(rhrs_dir)temp1 ]; then
                    rm $(rhrs_dir)temp1
                fi
            elif (( $non_spaces == 0 )); then
                rm $path #remove empty files
            fi
        fi
    done
}

## show visually pleasing list of what to rehearse today ##
function rehearse-todo
{
    found=0
    if (( $# != 0 )); then
        echo "Usage: ${FUNCNAME[0]}"
    else
        for path in $(rhrs_dir)*; do
            name=${path##*/} #remove longest matching prefix substring
            if [ $name = $(today) ]; then
                echo "Rehearse the following today:" # header
                while read line; do
                    descr=${line##*;}       # remove all prefixes with '*;'
                    startdate=${line%%;*}   # remove all suffixes with ';*'
                    course=${line%;*}       # remove one suffix with ';*'
                    course=${course#*;}     # remove one prefix with '*;'
                    lhs="$course: $descr"
                    size=${#lhs}            # length of string
                    padding=$(( 55-$size ))
                    printf "~ $lhs%-$(( $padding ))s (added: $startdate)\n"
                done < $path
                found=1 #set flag
            fi
        done
        if (( found == 0 )); then
            echo "nothing to rehearse today"
        fi
    fi
}

## show visually pleasing list of what to rehearse for all time ##
function rehearse-todo-all
{
    found=0
    if (( $# != 0 )); then
        echo "Usage: ${FUNCNAME[0]}"
    else
        for path in $(rhrs_dir)*; do
            name=${path##*/} #remove longest matching prefix substring
            if [ -f $path ]; then
                if [ $name = $(today) ]; then
                    echo "$name - rehearse following: <- TODAY"
                else
                    echo "$name - rehearse following:" # header for each day
                fi
                while read line; do
                    descr=${line##*;}       # remove all prefixes with '*;'
                    startdate=${line%%;*}   # remove all suffixes with ';*'
                    course=${line%;*}       # remove one suffix with ';*'
                    course=${course#*;}     # remove one prefix with '*;'
                    lhs="$course: $descr"
                    size=${#lhs}            # length of string
                    padding=$(( 55-$size ))
                    printf "~ $lhs%-$(( $padding ))s (added: $startdate)\n"
                done < $path
                found=1 #set flag
            fi
        done
        if (( found == 0 )); then
            echo "There is nothing to rehearse... ever."
        fi
    fi
}
