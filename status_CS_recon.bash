#!/bin/bash
# run workstation command with "rad_mat" which really just sets pipeline startup
#
# if you want to email output see email example below
if [ -z $1 ];then
    echo "please specify runno!";
    exit;
fi;
args="";
for arg in $@; do 
    if [ ! -z "$args" ];then
	args="$args,'$arg'";
    else
	args="'$arg'";
    fi;
done

cd ${WKS_SHARED}/pipeline_utilities;
#echo /usr/local/bin/matlab -nodesktop -noFigureWindows -nojvm -r "status_CS_recon($args);exit";exit;
/usr/local/bin/matlab -nodesktop -noFigureWindows -nojvm -r "status_CS_recon($args);exit"

# example cron job to send mail to some user.
#min     hour          day     month weekday
#52      5,11,16,21      *       *       *       source $HOME/.bashrc; status_CS_recon S67962 2>&1 | mail -s "status_CS_recon S67962" $USER@duke.edu







