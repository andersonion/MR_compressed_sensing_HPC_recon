#!/usr/bin/env bash
# a recon stopper, it will stop a recon with a given base runno....
# or course if you've used bad runnos they'll be stopped too.

# check if our required things are available
dn=$(type drain_nodes 2> /dev/null);
udn=$(type undrain_nodes 2>/dev/null);
if [ -z "$dn" -o -z "$udn" ];then
    echo "Error finding slurm helpers drain/undrain nodes" >&2;
    echo "aborting" >&2;
    exit 1;
fi;
# look for a warn_len var
warn_len="$2";
if [ -z "$warn_len" ];then
    warn_len=5;
fi;
echo "Warning: This is an untestd function! It should work, and use at own risk! pausing for $warn_len seconds.";
echo "ctrl+c to cancel.";
echo "specify warning length to shorten it";
sleep $warn_len;
if [ ! -z "$1" ];then
    base_runno=$1;
else
    echo "ERROR: Please specify your base_runno!";
    exit 1;
fi;

#obsolete.
#if [ ! -z "$PROTO_BIN" ];then
#    cd $PROTO_BIN
#else
#    echo "ERROR: no prototype bin for (drain|undrain)_node";
#    exit 1;
#fi;

list_file="$HOME/.CS_jobs_${base_runno}";
grep $base_runno $(slurm_queue_snapshot) > $list_file

if [ $(cat $list_file|wc -l) -le 0 ];then
    echo "No jobs in queue for $base_runno";
else
    echo "Now stopping any pending jobs for $base_runno, ";
    echo "WARNING";
    echo "WARNING:  running jobs will be allowed to complete!";
    echo "WARNING";
    echo "ctrl+c to cancel (and let work proceed).";
    sleep 2;
    drain_nodes || exit $?;
    scancel $(grep -vi run $list_file |awk '{print $1}'|xargs)
    undrain_nodes || exit $?;
fi;
