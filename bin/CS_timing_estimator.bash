#!/bin/bash
# run workstation command with "rad_mat" which really just sets pipeline startup
#
# if you want to email output see email example below
if [ -z $1 ];then
    echo "please specify runno!";
    exit;
fi;
cd ${WKS_SHARED}/pipeline_utilities;
# if anything is entered after BIGGUS_DISKUS re-collection is forced.
# That might be appropriate for once per day on long recons or something.
gather_CS_recon_meta $1 | tee ~/gather_tmp.m; # normal call
#gather_CS_recon_meta $1 $BIGGUS_DISKUS 1 > ~/gather_tmp.m; # with re-collect force
#/usr/local/bin/matlab -nodisplay -nosplash -nodesktop -noFigureWindows -r "run('~/gather_tmp.m');exit;" && rm ~/gather_tmp.m

# example cron job to send mail to some user.
#min     hour          day     month weekday
#52      5,16      *       *       *       source $HOME/.bashrc; CS_timing_estimator S67962 1 2>&1 | mail -s "CS_timing_estimator" $USER@duke.edu
