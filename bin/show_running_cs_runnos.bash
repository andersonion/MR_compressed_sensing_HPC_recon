#!/bin/bash
# show the running cs_recon runnos for specified user, (or you).

the_user=$USER;
if [ ! -z "$1" ];then
    the_user=$1;
fi;

stat_queue=$("slurm_queue_snapshot" $the_user);
#echo "queue_capture=$stat_queue" >&2
# old slower version
#for jn in $(cat $stat_queue |cut -b 25-68 |xargs); do echo $jn|cut -b 1-6; done |sort -u
# This filters the stat file to column3, then uses regular expression to find
# any entry on that line looking like a simple runo.
# This is unnecessarily specific, we dont have to limit ourselves to col3 in the case we adjust the order.
#awk '{print $3}' $stat_queue |tail -n +2 |sed -E 's/.*([A-Z][0-9]+).*/\1/g'|sort -u

# cant tune the sed line to only print first match, figured out the perlism for this
#tail -n +2 $stat_queue | sed -nE 's/^(.*)([A-Z][0-9]+)(.*)$/\2/p'|sort -u
tail -n +2 $stat_queue | perl -ne 'print "$1\n" if /([A-Z][0-9]+)/'|sort -u
