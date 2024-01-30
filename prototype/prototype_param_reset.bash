#!/usr/bin/env bash
#
# when we need to reset param files we have to run this script.
# this is phase3 of a reset.
# phase1 inserts the U_params into the recon mat file from matlab.
#
runno="N60822";
n=66;
# matlab_run to run phase 1 and 2?
#code_dir=/cm/shared/workstation/code/recon/CS_v3/prototype/;
code_dir="$PWD";
matlab_run "runno='$runno';n=$n;run('$code_dir/prototype_param_reset_recon.m');exit();";
matlab_run "runno='$runno';n=$n;run('$code_dir/prototype_param_reset_update_initial_hf.m');exit();";

BD=$BIGGUS_DISKUS;
cd $BD/$runno.work;
while read rdir;
do
    n=${rdir#*/};
    bhf=$n/${n}.bak;
    fhf=$n/${n}images/$n.headfile;
    pl=$(grep -c U_ $fhf);
    if [ "$pl" -lt 15 ];
    then
	mv $bhf $fhf;
	find $rdir -maxdepth 1 -name "sent_hf*" -delete 
    fi;
done < <(find . -mindepth 1 -maxdepth 1 -type d)
