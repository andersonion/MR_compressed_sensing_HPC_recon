#!/bin/bash
# a cs recon throttler keeping some N of volumes running at a time. 
# uses tags deep in result dirs to check if we should add one, 
# checking interval to be handled by cron job, 
# 
# 
# !!!!!  THIS IS NOT GENERALIZED YET!!!  !!!!!
#
# this uses hardcoded scanner, runno, iterstrat, chunk_size
# kamy, S67962, 10x5, 10
# 
# ALSO FORCING LATEST EXEC's
#
declare -x CS_CODE_DEV=latest;
if [ -z "$1" ];then
    concurrent_vols=5;
else
    concurrent_vols=$1;
fi;
if [ -z "$2" ];then 
    wkdir=$PWD;
else 
    wkdir=$2;
fi;
if [ -z "$3" ]; then
    # set verbose.
    v=0;
else 
    v=1;
fi;
# get max_volumes
# grep dti_vols=110
hf=$(ls -t $wkdir/*headfile|tail -n 1)
#[s,o]=system(sprintf('sed -rn ''s/.*(--reservation.*)/\\1/p'' %s',batch_file));
if [ ! -f $hf ];then
    echo "Cant operate without a processed headfile ! THIS IS NOT A REPLACMENT FOR STREAMING MODE.";
    exit;
fi;
max_vols=$(sed -rsn 's/.*dti_vols=(.*)/\1/p' $hf);
vn_len=${#max_vols};


# get volumes in operation, 
# started vols is mnums in currentdir.
started=$(ls -d $wkdir/*_m*| sed -rn 's/.*_m([0-9]+)$/\1/p' );
if [ $v -eq 1 ];then echo "Started:$started"|xargs; fi;
completed="";
#.S67962_m000_send_archive_tag_to_delos_SUCCESSFUL
#.S67962_m000_send_headfile_to_delos_SUCCESSFUL
#.S67962_m000_send_images_to_delos_SUCCESSFUL
for vn in $started; do 
    # success count, we're looking for 3.
    sc=$(ls -A $wkdir/*_m$vn/*images/|grep -c SUCCESSFUL);
    if [ $sc -eq 3 ];then
	completed="$completed $vn";
	# completed file, can/should remove the throttle for book keeping.
	let vn=$vn+0;# convert from 0 padded string to number.
	tf="$wkdir/.throttle_$vn";
	if [ ! -z "$tf" -a -f "$tf" ];then 
	    rm "$tf";
	fi;
    fi;
done
th_count=$(ls -A $wkdir/ |grep -c .throttle_);
if [ $v -eq 1 ];then echo "Completed:$completed";fi;
let in_progress_count=$(echo $started|wc -w )-$(echo  "$completed"| wc -w)+$th_count;
if [ $in_progress_count -lt $concurrent_vols ]; then
    # get next viable vol
    for((vn=0;$vn<=$max_vols;vn=$vn+1)); do 
	found=$(echo $started | grep -c $(printf "%0${vn_length}i" $vn) ); 
	let nv=$vn+1;# handle the 1 vs zero indexing :b
	# throttle file
	tf="$wkdir/.throttle_$vn";
	if [ "$found" -eq 1 -o -f $tf ];then
	    # started or in queue. try next.
	    continue;
	elif [ "$found" -eq 0 ];then
	    break;
	else
	    echo "unexpected number count ($found) in started ($vn), somethings's gone wrong!";
	    exit;
	fi;
    done
    let nv=$vn+1;# handle the 1 vs zero indexing :b
    # throttle file
    tf="$wkdir/.throttle_$vn";
    if [ ! -f $tf ]; then 
	echo "Scheduling vn:$nv";exit;
	touch $tf
	streaming_CS_recon kamy S67962 LOCAL FID first_volume=$nv last_volume=$nv iteration_strategy=10x5 planned_ok chunk_size=10
    fi;
else
    if [ $v -eq 1 ];then echo "Enough running:$in_progress_count >= $concurrent_vols";fi;
fi;

#total_done+scheduled
let mc=$(echo $started|wc -w )+$th_count;
if [ $mc -ge $max_vols ]; then
    echo "Scans done being scheduled, We should stop this cron job now, attempting auto off. Sorry this clobbers all lines for this program.";
    pname=$(basename $0);echo REMOVING ALL CRON LINES WITH $pname;
    crontab -l >> $HOME/${pname}_crontab.bak
    crontab -l |grep -v $pname |crontab -
fi;
