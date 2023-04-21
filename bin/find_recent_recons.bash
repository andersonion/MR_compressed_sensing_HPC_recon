#!/usr/bin/env bash
# Find recent runs given a projet code.
# using the param files directory which is a cache of
# different runno.param files (for all users)
# this will check recon status for all and give a
# report (of sorts) combining ls -l output and total recon complete
#
# This is more than a little civm CS recon specific, and should probably migrate there.

if [ -z "$1" ];then
    echo "Please specify project code(partial okay), user biggus(if needed), and limit of status checked files. This checks in order from newest to oldest." 1>&2;
    exit 1;fi;

if [ -z "$2" ];then
    USER_BIGGUS="";
else
    USER_BIGGUS="$2";
fi;

if [ -z "$3" ];then
    limit=500;
else
    limit="$3";
fi;

#proj=20.5xfad
proj="$1";

# complete check done in parallel, this is our limit
MAX_PARALLEL=24

param_files=$(ls -t $(grep -R "$proj" $WKS_HOME/dir_param_files/ 2> /dev/null |cut -d ':' -f1|grep -v 'lastsettings') |head -n "$limit");
runnos="";
status_files="";
# THIS COULD STAND IMPROVEMENT
status_dir="$HOME/CS_recon_status";
for f in $param_files;
do n=$(basename $f);
    rn=${n%.*};
    if [ -z "$rn" ];then
        continue;fi;
    ext=${n##*.};
    if [ "$ext" != "param" ];then
        continue; fi;
    runnos="$runnos $rn";
    # old status file
    #stf=~/CS_recon_${rn}.status;
    # new status
    stf="$status_dir/${rn}.status";
    status_files="$status_files $stf";
    #if [ ! -e $stf ];
    #then
    #echo "Collecting status for $rn";
    status_CS_recon $rn $USER_BIGGUS &
    #fi;
    while [ $(jobs |wc -l) -gt $MAX_PARALLEL ];do
        echo "Too many jobs checking in parallel waiting";
        sleep 5
    done
done
echo "Waiting for status collection to finish" >&2
wait

# for f in $param_files;
# do n=$(basename $f);
#     rn=${n%.*};
#     if [ -z "$rn" ];then
#       continue;fi;
#     ext=${n##*.};
#     if [ "$ext" != "param" ];then
#       continue; fi;
#     stf=~/CS_recon_${rn}.status;
#     #grep -c 'Starting point'  ~/CS_recon_N58798.status
#     if [ ! -e $stf ]; then
#       echo "Status collect failed on $rn" 1>&2;
#     fi;
echo "Status files:$status_files" 1>&2;
# show status files in newest to oldest via ls -t
for stf in $(ls -t $status_files); do
    volume_count=$(grep -c 'Starting point' "$stf");
    echo -n "$(cd $(dirname $stf);ls -l $(basename $stf))  - N=$volume_count - "
    grep -i total $stf||echo "";
done
