#!/bin/bash
# a recon stopper, it will stop a recon with a given base runno....
# or course if you've used bad runnos they'll be stopped too.
echo "Warning: This is an untestd function! It should work, and use at own risk! pausing for 5 seconds.";
echo "ctrl+c to cancel.";
sleep 5;
if [ ! -z "$1" ];then
    base_runno=$1;
else 
    echo "ERROR: Please specify your base_runno!";
    exit 1; 
fi;

if [ ! -z "$PROTO_BIN" ];then
    cd $PROTO_BIN
else 
    echo "ERROR: no prototype bin for (drain|undrain)_node";
    exit 1; 
fi;

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
    drain_nodes
    scancel $(grep -vi run $list_file |awk '{print $1}'|xargs)
    undrain_nodes
fi;
