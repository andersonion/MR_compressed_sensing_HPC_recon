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
# ALSO FORCING EXEC's to specified version
#
declare -x CS_CODE_DEV=iter_strat_v3;
if [ -z "$1" ];then
    concurrent_vols=5;
else
    concurrent_vols=$1;
fi;
if [ -d "$2" ];then
    wkdir=$2;
    #temp workfolder name to get base runno
    t_wkf=$(basename $wkdir);
    bd=$(dirname $wkdir);
    if [ $bd != $BIGGUS_DISKUS ];then
	echo "ERROR: different temp space, \"$bd\" is not \"$BIGGUS_DISKUS\"";
	exit 1;
    fi;
    base_runno=${t_wkf%.*};
else 
    base_runno=$2;
    wkdir=$BIGGUS_DISKUS/$2.work;
fi;

if [ ! -d $wkdir ];then
    echo "error setting base_runno and wkdir";
    echo "base_runno:$base_runno, wkdir:$wkdir";
    exit;
fi;
#verbose verbosity
v=0;
if [ -n "$3" ]; then
#    echo "($3)";
    v=$3;
    # these if condistions are finicky, and it wasnt clear why. 
    #if [[ "n"="$3" ]];# -o "$3"="false" -o "$3"="False" ];
    if [ "X_$3"="X_false" ];
    then
	# no op because conditions are easier to think about.
	echo -n '';
#    else
#	echo "verbose on"
#	v=1;
    fi;
fi;
#echo $3 $v ; exit;
#streaming_mode=0;
if [ -n "$4" ]; then
    max_vols=$4;
fi;

# how many volumes to skip
vol_step=1;
if [ -n "$5" ]; then 
    vol_step=$5;
fi;

# skip some n volumes to catch up
skipped_vols=0;
if [ -n "$6" ];then
    skipped_vols=$6;
fi;

# feed back when verbose
if [ $v -eq 1 ];then
    echo "base_runno:$base_runno, wkdir:$wkdir";
    if [ -n "$max_vols" ]; then    
	echo "max vol override to $max_vols set(which we have to do when streaming) ";
    fi;
    echo "using volume step of $vol_step, skipping past $skipped_vols";
fi;

###
# get max_volumes
###
if [ -z "$max_vols" ]; then
    # grep dti_vols=110
    #hf=$(ls -t $wkdir/*headfile|tail -n 1)
    hf=$(find $wkdir -maxdepth 1 -name "*headfile")
    #[s,o]=system(sprintf('sed -rn ''s/.*(--reservation.*)/\\1/p'' %s',batch_file));
    if [ -z "$hf" -o ! -f "$hf" ];then
	echo "Cant operate without a processed headfile ! THIS IS NOT A REPLACMENT FOR STREAMING MODE.";
	exit;
    fi;
    max_vols=$(sed -rsn 's/.*dti_vols=(.*)/\1/p' $hf);
fi;
vn_len=${#max_vols};

###
# get volumes which have been started.
# this is hard beacause we may have completed volumes, or not really running volumes who have their base folder.
# we can find volumes in current operation using the tmp files, 
# we can find cleaned volumes because they'll be missing work folders
voldir_list=$(find $wkdir -maxdepth 1 -regextype posix-extended -regex ".*${base_runno}_m[0-9]+$");
#voldir_count=$(echo $voldir_list|wc -w);

#example find temps  ls $BIGGUS_DISKUS/S68041qa.work/*/work/*tmp
#voldir_count=$(find $wkdir -maxdepth 1 -regextype posix-extended -regex ".*${base_runno}_m[0-9]+$"|wc -l);
# any existing work dir must have contents to count. So
# started is any with a work dir, and tmp file in it, OR missing it work file entirely.

# simple, started vols is mnums in currentdir.
# started=$(ls -d $wkdir/*_m*| sed -rn 's/.*_m([0-9]+)$/\1/p' );
# complex started based on found tmp files. This is only part of the started group. This wouldnt count completed scans.
started=$(find $wkdir -mindepth 3 -maxdepth 3 -regextype posix-extended -regex ".*${base_runno}_m[0-9]+.tmp$"  -exec basename {} \; | sed -rn 's/.*_m([0-9]+).tmp$/\1/p' ); 

# finding cleaned relies on work dirs being created right away. 
#echo "checking for cleaned";
cleaned=$( for vd in $voldir_list;    do if [ ! -d $vd/work ];	then echo $(basename $vd);fi; done|sed -rn 's/.*_m([0-9]+).*/\1/p';);
started="$started $cleaned"
if [ $v -eq 1 ];then
#    echo "voldirs:$voldir_count $voldir_list";
    echo "Started:$started"|xargs; 
fi;
completed="";
#.S67962_m000_send_archive_tag_to_delos_SUCCESSFUL
#.S67962_m000_send_headfile_to_delos_SUCCESSFUL
#.S67962_m000_send_images_to_delos_SUCCESSFUL
for vn in $started; do 
    # success count, we're looking for 3, but for stream throttling we only wanna check images...
    #sc=$(ls -A $wkdir/*_m$vn/*images/|grep -c SUCCESSFUL);
    mn="${base_runno}_m${vn}";
    img_flag=$(find $wkdir/${mn}/${mn}images/ -name ".${mn}_send_images*SUCCESSFUL");
    #if [ $sc -eq 3 ];then
    if [ -n "$img_flag" ];then
	completed="$completed $vn";
    fi;
    # once a volume is started the throttle holding place is no longer needed.
    # remove the throttle for book keeping.
    let vn=10#$vn+0;# convert from 0 padded string to number.
    tf="$wkdir/.throttle_$vn";
    if [ ! -z "$tf" -a -f "$tf" ];then 
	rm "$tf";
    fi;
done

if [ $v -eq 1 ];then echo "Completed:$completed";fi;
th_count=$(ls -A $wkdir/ |grep -c .throttle_);
let in_progress_count=$(echo $started|wc -w )-$(echo  "$completed"| wc -w)+$th_count;
###
# get activity log entry
###
# This first version forces user to have set first_volume and last_volume, but really we dont wanna do that.
#act_log_entry=$(grep -E "streaming_CS_recon.*$base_runno" $BIGGUS_DISKUS/activity_log.txt|tail -n1|sed -rn 's/.*(streaming_CS_recon.*first_volume=[0-9]+.*last_volume=[0-9]+.*)/\1/p');
act_log_entry=$(grep -E "streaming_CS_recon.*$base_runno " $BIGGUS_DISKUS/activity_log.txt|tail -n1|sed -rn 's/.*(streaming_CS_recon[[:space:]]+.*)/\1/p');

#first_requsted=$(echo $act_log_entry|sed -rn 's/.*first_volume=([0-9]+).*/\1/p');
if [ -z "$first_requested" ];then
    first_requested=1;
fi;

#last_requested=$(echo $act_log_entry|sed -rn 's/.*last_volume=([0-9]+).*/\1/p');
#if [ -z "$last_requestd" -o $first_requested=$last_requested ];then
#    last_requested=$max_vols;
#fi;
# filter log entry removing first volume and last volume to create a template command.
cmd_template=$(echo -n $act_log_entry|sed -r 's/(.*)first_volume=[0-9]+(.*)/\1 \2/p');
cmd_template=$(echo -n $cmd_template|sed -r 's/(.*)last_volume=[0-9]+(.*)/\1 \2/p');
if [ $in_progress_count -lt $concurrent_vols ]; then
    # get next viable vol to start, beginning our search at the start. 
    # I think we could begin the search at a higher number, which for our QA problem we want to do.
    for((vn=$first_requested-1;$vn<=$max_vols;vn=$vn+$vol_step)); do 
	found=$(echo $started | grep -c $(printf "%0${vn_length}i" $vn) ); 
	let nv=10#$vn+1;# handle the 1 vs zero indexing :b
	# throttle file
	tf="$wkdir/.throttle_$vn";
	if [ "$found" -eq 1 -o -f $tf -o $vn -lt $skipped_vols ];then
	    if [ $v -eq 1 ]; then echo skipping $vn; fi;
	    # started or in queue. try next.
	    continue;
	elif [ "$found" -eq 0 ];then
	    break;
	else
	    echo "unexpected number count ($found) in started ($vn), somethings's gone wrong!";
	    exit;
	fi;
    done
    let nv=10#$vn+1;# handle the 1 vs zero indexing :b
    # throttle file
    tf="$wkdir/.throttle_$vn";
    if [ ! -f $tf ]; then 
	echo "Scheduling vn:$nv";
	if [ $v -eq 1 ];then
	    echo "in 4 seconds";
	    sleep 4;
	fi;
	touch $tf
# proximate original hardcdoded bits.
#	streaming_CS_recon kamy S68041qa LOCAL FID first_volume=$nv last_volume=$nv iteration_strategy=10x5 skip_fermi_filter planned_ok chunk_size5=
# formerly used CS_reservation, will not for the time being.
# CS_reservation=jjc29_33;
# proximate new hardcdoded bits.
# 	streaming_CS_recon	kamy $base_runno S68040_03 ser02 CS_table=CS1152_24x_pa18_pb90 iteration_strategy=10x2 Itnlim=20 xfmWeight=0.002 TVWeight=0.0012 target_machine=delos first_volume=$nv last_volume=$nv planned_ok chunk_size=3 skip_fermi_filter
	if [ $v -eq 1 ];then
	    echo act_log:$act_log_entry;
	    echo cmd_t:$cmd_template;
	fi;
	$cmd_template first_volume=$nv last_volume=$nv 
    fi;
    exit;
else
    if [ $v -eq 1 ];then echo "Enough running:$in_progress_count >= $concurrent_vols";fi;
fi;
#total_done+scheduled
let mc=10#$th_count+$(echo $started|wc -w );
if [ $mc -ge $max_vols ]; then
    echo "Scans done being scheduled, We should stop this cron job now, attempting auto off. Sorry this clobbers all lines for this program.";
    pname=$(basename $0);echo REMOVING ALL CRON LINES WITH $pname and $base_runno;
    crontab -l >> $HOME/${pname}_crontab.bak
    crontab -l |grep -v $pname|grep -v $base_runno |crontab -
fi;
