#!/bin/bash
#  captures snaptshot of squeue for user, at most every three minutes 
#  echos the name of file captured to feed into the next thing.

the_user=$USER;
if [ ! -z "$1" ];then
    the_user=$1;
fi;

touch -t $(date -d "3 mins ago" +%Y%m%d%H%M.%S) ${HOME}/.queue_anchor_${the_user}
stat_queue=${HOME}"/.queue_${the_user}";
generate=1;
if [ -f $stat_queue -a $stat_queue -nt ${HOME}/.queue_anchor_${the_user} ]; then
    generate=0;
fi

if [ $generate -eq 1 ];then
    squeue  -o "%.12i %.9P %.40j %.8u %.6T %.10M %.9l %.6D %R" -u ${the_user} > $stat_queue
fi;
echo $stat_queue
