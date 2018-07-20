#!/bin/bash
# run workstation command with "rad_mat" which really just sets pipeline startup
#
# if you want to email output see email example below
if [ -z $1 ];then
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

cd ${WKS_SHARED}/pipeline_utilities;
#echo /usr/local/bin/matlab -nodesktop -noFigureWindows -nojvm -r "status_CS_recon($args);exit";exit;
lck_file=$HOME/CS_recon_S6796.lck
if [ ! -f $lck_file ]; then 
    touch $lck_file
    /usr/local/bin/matlab -nodisplay -nosplash -nodesktop -noFigureWindows -r "status_CS_recon($args);exit"
    rm $lck_file; 
else 
    touch -t $(date -d "1 day ago" +%Y%m%d%H%M.%S) ${HOME}/.queue_anchor_lck_tst
    if [ $lck_file -ot ${HOME}/.queue_anchor_lck_tst ];then
	rm $lck_file;
    fi;
    echo "lock file $lck_file still exists from previous run, maybe we're calling too often? OR we crashed...";
    if [ ! -f $lck_file ]; then
	echo "lock file was older than a day so we just trashed it";
    fi;
    rm ${HOME}/.queue_anchor_lck_tst
fi;

# example cron job to send mail to some user.
#min     hour          day     month weekday
#52      5,11,16,21      *       *       *       source $HOME/.bashrc; status_CS_recon S67962 2>&1 | mail -s "status_CS_recon S67962" $USER@duke.edu

# send output without new image files, but saving output to file in users home dir.
#16	5,11,16,21	*	*	*	source $HOME/.bashrc; t_run="S67962";s_file=$HOME/CS_recon_${t_run}.status;status_CS_recon $t_run 2>&1 > $s_file; cat $s_file| mail -s "status_CS_recon $t_run" $USER@duke.edu
# send output with image files
#15	5,11,16,21	*	*	*	source $HOME/.bashrc; t_run="S67962";s_file=$HOME/CS_recon_${t_run}.status;status_CS_recon $t_run Write 2>&1 > $s_file; attachments=$(grep -- '->' ${s_file} |awk '{print $2}'); cat $s_file| mail -s "status_CS_recon $t_run"  $USER@duke.edu; for at in  $attachments ; do if [ ! -z "$at" ]; then echo "See attached $at" | mail -s "status_CS_recon $t_run $(basename ${at%.*})" -a $at $USER@duke.edu ;fi;donep






