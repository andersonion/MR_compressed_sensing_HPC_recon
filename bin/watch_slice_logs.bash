#!/bin/bash
# runs tail -f on current slice jobs for the specified user, (or you).
# this was made to watch multiple cleanup jobs not slice jobs,
# but since they have the same name for singleton purposes it does all at once.
# filtering might be possible but was not currently attempted.


the_user=$USER;
if [ ! -z "$1" ];then
    the_user=$1;
fi;
the_partition='.*'
if [ ! -z "$2" ];then
    the_partition=$2;
fi;
the_pattern='slices_per_job'

hlpr_dir="$WKS_HOME/recon/CS_v2/bin";

# find logs of running CS_slice jobs processes, and tail -f them
# Uses a static capture of squeue, generated by the slurm_queue_snapshot helper in pipeline utilities
#tail -f $(
#    for id in $(cat $stat_queue |grep -i run |grep -i slices_per_job|cut -b 1-13);
#    do echo $(scontrol show job  $id |grep StdOut|xargs|cut -d '=' -f2);
#    done|xargs);

$hlpr_dir/watch_CS_logs.bash $the_user $the_partition $the_pattern
