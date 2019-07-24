#!/bin/bash
# CS_streaming main code. Used to control the latest vs stable vs picka version code when running streaming main.
# James cook 20171207
if [ -z "$CS_CODE_DEV" ]; then
    declare -x CS_CODE_DEV=stable;
fi;
exec_path="$WORKSTATION_HOME/matlab_execs/streaming_CS_recon_main_executable/$CS_CODE_DEV/run_streaming_CS_recon_main_exec_builtin_path.sh";
if [ ! -f $exec_path ]; then 
echo "ERROR: Missing $CS_CODE_DEV exec!($exec_path)";
echo "Available exec versions...";
ls -tr $WORKSTATION_HOME/matlab_execs/streaming_CS_recon_main_executable/
exit;
fi;
# added chunk size force to try to make cs_recon easier on the slurm scheduler. 
chunk_size_set=$(echo $@ |grep -c chunk_size);
c_force="";
if [ $chunk_size_set -eq 0 ] ;then 
    c_force="planned_ok chunk_size=30";
fi;
echo "# start $CS_CODE_DEV exec ($exec_path)"
echo "# with args ( $@ $c_force)";
# this echo captures the command used to the activity_log. 
# It might be good to use the activity_log matab function, but I dont think it works for execs.
echo -e "$(date +"%F_%T")\t$USER\t$0\t$@ $c_force" >> $BIGGUS_DISKUS/activity_log.txt
# Run recon.
$exec_path $@ $c_force



# advice on $@ and other things.
# https://stackoverflow.com/questions/12314451/accessing-bash-command-line-args-vs
#If the arguments are to be stored in a script variable and the arguments are expected to contain spaces, I wholeheartedly recommend employing a "$*" trick with the internal field separator $IFS set to tab.
