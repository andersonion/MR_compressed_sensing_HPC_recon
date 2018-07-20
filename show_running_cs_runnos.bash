#!/bin/bash
# show the running cs_recon runnos for specified user, (or you).

the_user=$USER;
if [ ! -z "$1" ];then
    the_user=$1;
fi;
hlpr_dir="$WKS_HOME/recon/CS_v2";
stat_queue=$("$hlpr_dir/capture_squeue.bash" $the_user);

for jn in $(cat $stat_queue |cut -b 25-68 |xargs); do echo $jn|cut -b 1-6; done |sort -u
