#!/bin/bash
# show the running jobs for a cs_recon runno(or sub runno) for specified user, (or you).
# show runno(sub)
# show runno(sub) user

the_runno="BLARG";
if [ -z "$1" ];then
    echo "Must specify runno OR subrunno";
    exit 1;
else
    the_runno="$1";
fi;

the_user=$USER;
if [ ! -z "$2" ];then
    the_user="$2";
fi;


stat_queue=$("slurm_queue_snapshot" "$the_user");
#echo "queue_capture=$stat_queue"
#echo "Looking up jobid's for $the_runno";
ids=$(grep -i  run $stat_queue|grep -iE "$the_runno" |awk '{print $1}');
echo "$ids";
# this is a list of files.
#list=$(for id in $(echo $ids|xargs);
#    do echo $(scontrol show job  $id |grep StdOut|xargs|cut -d '=' -f2);
#    done|xargs);
