#!/bin/bash
# run status_CS_recon matlab code with all the script args
# effectively a wrapper for that matlab function.
#
# Very nearly a generalized run matlab code named like script.
runno="$1";
if [ -z "${runno}" ];then
    echo "please specify runno!";
    exit;
fi;
args="";
for arg in $@; do
    if [ ! -z "$args" ];then
        args="$args,'$arg'";
    else
        args="'$arg'";
    fi;
done
USER_BIGGUS="$BIGGUS_DISKUS";
if [ ! -z "$2" ];then
    USER_BIGGUS="$2";
fi;
if [ ! -d "$USER_BIGGUS" ];then
    echo "ERROR: missing dir $USER_BIGGUS" 1>&2;
    exit 1;
fi;

cd ${WKS_SHARED}/pipeline_utilities;
#echo /usr/local/bin/matlab -nodesktop -noFigureWindows -nojvm -r "status_CS_recon($args);exit";exit;
s_file_raw=$HOME/".CS_recon_${runno}.rstatus";
s_file=$HOME/"CS_recon_${runno}.status";

log_file=$(ls -dtr "$USER_BIGGUS/${runno}.work/${runno}"*"recon"*"log" 2> /dev/null |tail -n1);
if [ -z "$log_file" ];then
    echo "Cant get log file ${runno}*recon*log in $USER_BIGGUS/${runno}.work" 1>&2;
    exit 1;
fi;

# use a lock file to prevent double running in case that happens accidentially.
# but, that adds complication of potentially stuck locks.
lck_file=$HOME/".CS_recon_${runno}_status.lck";
lck_stuck_t=${HOME}/".CS_recon_${runno}_status.t_anchor"

#TIME_STRING="1 day ago";
TIME_STRING="5 minutes ago";
TIME_STRING="1 minute ago";
touch -t $(date -d "$TIME_STRING" +%Y%m%d%H%M.%S) "$lck_stuck_t";
if [ -f "$lck_file" ]; then
    if [ "$lck_file" -ot "$lck_stuck_t" ];then
        rm "$lck_file";
    fi;
    echo "lock file $lck_file still exists from previous run, maybe we're calling too often? OR we crashed...";
    if [ ! -f "$lck_file" ]; then
        echo "lock file was older than $TIME_STRING so we just trashed it";
    fi;
fi;

if [ ! -f "$lck_file" ]; then
    #
    # touch "$lck_file" && /usr/local/bin/matlab -nodisplay -nosplash -nodesktop -noFigureWindows -r "status_CS_recon($args);exit" 2>&1 > "$s_file_raw" && sed 's/[^[:print:]]//g' "$s_file_raw" > "$s_file" && rm "$lck_file";
    s_last="NO_LAST";
    skip_collect=0;
    run_error=0;
    if [ ! -e "$log_file" -o ! -e "$s_file" ] ||
        [ -e "$log_file" -a -e "$s_file" -a "$log_file" -nt "$s_file" ];
    then
        echo -n "Collecing data beacuase"
        if [ ! -e "$log_file" -o ! -e "$s_file" ]; then
            echo " missing $s_file or $log_file";
        elif [ -e "$log_file" -a -e "$s_file" -a "$log_file" -nt "$s_file" ]; then
            echo " newer $log_file";
        fi;
        if [ -f "$s_file" ];then
            echo -n '';
            # old file existts... lets stash it
            s_last="$(basename ${s_file})";
            s_last="$(dirname ${s_file})/${s_last%.*}.last";
            mv -f "$s_file" "$s_last";
        fi;
        # | sed 's/[^[:print:]]//g'
        # | perl -pi -e 's/[^[:ascii:]]//g'
        # | perl -ne 'print "$1\n" if /((?:[0-9]+[.][0-9]+%|stage|total).*$)/i'
        # log file and status exist, and log file is older, then  we dont need to update.
        touch "$lck_file" && /usr/local/bin/matlab -nodisplay -nojvm -nosplash -nodesktop -noFigureWindows -r "status_CS_recon($args);exit" 2>&1 > "$s_file_raw" && grep  -iE '([0-9]+[.][0-9]+%|stage|total)' "$s_file_raw"  | perl -ne 'print "$1\n" if /((?:[0-9]+[.][0-9]+%|stage|total).*$)/i' > "$s_file" || run_error=1;
        #if [ -e "$log_file" -a -e "$s_file" -a "$log_file" -ot "$s_file" ];then

        if diff -s "$s_file" "$s_last" > /dev/null; then
            # identicle
            # preserve timestamp by squashing current f.
            mv -f "$s_last" "$s_file";
        else
            # different, keep updated remove last
            rm "$s_last";
        fi;
        #ls -lt $lck_stuck_t $s_file;
    else
        skip_collect=1;
    fi;
    if [ "$s_file" -ot "$lck_stuck_t" -a $skip_collect -eq 0 ];then
        hchk=$(cluster_status_CS_recon);
        if [ "$hchk" == "Healthy" ];then
            echo "Not to worry, cluster is healthy";
        else
            echo "WARNING: Cluster unhealthy!" >&2;
        fi;
        echo -n "no progress since $TIME_STRING $s_file:"
    else
        echo -n "$s_file:";
    fi;
    if [ -e "$log_file" ];then
        touch -r "$log_file" "$s_file";
    fi;
    grep -i total "$s_file"

    if [ $run_error -eq 0 -a $skip_collect -eq 0 ];then
        rm "$lck_file" && rm "$s_file_raw";
    fi;
    if [ -e "$s_file_raw" ];then
        cat "$s_file_raw";
        echo "ERROR collecting status" >&2;
        exit 1;
    fi;
    #touch "$lck_file" && /usr/local/bin/matlab -nodisplay -nosplash -nodesktop -noFigureWindows -r "status_CS_recon($args);exit" 2>&1 | sed -r s'/^[^0-9T]*([0-9]+[.]|[Tt][Oo][Tt][Aa][Ll])(.+$)/\1\2/' > "$s_file" && rm "$lck_file";
fi;
rm "$lck_stuck_t";

# example cron job to send mail to some user.
#min     hour          day     month weekday
#52      5,11,16,21      *       *       *       source $HOME/.bashrc; status_CS_recon S67962 2>&1 | mail -s "status_CS_recon S67962" $USER@duke.edu

# send output without new image files, but saving output to file in users home dir.
#16     5,11,16,21      *       *       *       source $HOME/.bashrc; t_run="S67962";s_file=$HOME/CS_recon_${t_run}.status;status_CS_recon $t_run 2>&1 > $s_file; cat $s_file| mail -s "status_CS_recon $t_run" $USER@duke.edu
# send output with image files
#15     5,11,16,21      *       *       *       source $HOME/.bashrc; t_run="S67962";s_file=$HOME/CS_recon_${t_run}.status;status_CS_recon $t_run Write 2>&1 > $s_file; attachments=$(grep -- '->' ${s_file} |awk '{print $2}'); cat $s_file| mail -s "status_CS_recon $t_run"  $USER@duke.edu; for at in  $attachments ; do if [ ! -z "$at" ]; then echo "See attached $at" | mail -s "status_CS_recon $t_run $(basename ${at%.*})" -a $at $USER@duke.edu ;fi;donep
