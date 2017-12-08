#!/bin/bash
# CS_streaming main code. Used to control the latest vs stable vs picka version code when running streaming main.
# James cook 20171207
echo $CS_CODE_DEV
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
echo "# start exec ($exec_path)"
echo "# with args ($@)";
$exec_path $@

# advice on $@ and other things.
# https://stackoverflow.com/questions/12314451/accessing-bash-command-line-args-vs
#If the arguments are to be stored in a script variable and the arguments are expected to contain spaces, I wholeheartedly recommend employing a "$*" trick with the internal field separator $IFS set to tab.
