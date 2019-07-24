#!/bin/bash
# show the running cs_recon runnos for specified user, (or you).

the_user=$USER;
if [ ! -z "$1" ];then
    the_user=$1;
fi;

stat_queue=$("slurm_queue_snapshot" $the_user);
echo "queue_capture=$stat_queue"
# old slower version
#for jn in $(cat $stat_queue |cut -b 25-68 |xargs); do echo $jn|cut -b 1-6; done |sort -u
awk '{print $3}' $stat_queue |sed -E 's/.*([A-Z][0-9]+).*/\1/g'|sort -u

