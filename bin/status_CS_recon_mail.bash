#!/bin/bash
# status and mail images
# status_CS_recon_mailer
if [ -z $1 ];then
    echo "please specify runno!";
    exit;
fi;
t_run=$1;shift
args="";
for arg in $@; do
    if [ ! -z "$args" ];then
        args="$args,$arg";
    else
        args="$arg";
    fi;
done

s_file=$HOME/CS_recon_${t_run}.status;
#status_CS_recon $t_run Write 2>&1 > $s_file;
#cat $s_file| mail -s "status_CS_recon $t_run"  $USER@duke.edu;

attachments=$(grep -- '->' ${s_file} |awk '{print $2}'|sed 's/[^[:print:];&]//g');
for at in  $attachments ;
do if [ ! -z "$at" ];
    then echo "See attached $at" | mail -s "status_CS_recon $t_run $(basename ${at%.*})" -a $at $args ;
    fi;
done

exit 0;
# Could convert to use mail_dir to send one series of mail.
# Only really important if we've got more than one attachment.
# Someting like, mkdir good subjname; foreach attacmnent ln -s $attachment
# Decided aginst it because we'd rather get these one at a time with their volumename.
