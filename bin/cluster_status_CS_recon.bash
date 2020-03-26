#!/usr/bin/env bash
# Report on cluster health status... When healthy will just echo Healthy and quit.
# if unhealthy will detail why. 

debugging=0;
minGiB=2;
err_m="";
for rx in $(show_running_cs_runnos all );
do 
    if [ $debugging -gt 0 ]; then echo check $rx;fi;
    rx_jobs=$(show_runno_jobs $rx all|wc -l);
    rx_run=$(show_runno_jobs_running $rx all|wc -l);
    if [ "$rx_run" -eq 0 ];then
	err_m+="$rx $rx_jobs in queue, but none are running!\n";
    fi
done

# read var1 var2 <<< ABCDE-123456
# df -Pk /var
#Filesystem     1024-blocks     Used Available Capacity Mounted on
#/dev/md3          31425544 23707960   7717584      76% /var
mount_points="/ /var/ /tmp/ /civmnas4/cof/"
for mount in $mount_points; do 
    if [ $debugging -gt 0 ]; then echo check $mount;fi;
    read FS TotalKiB UsedKiB AvailKiB PctUsed mount <<< $( df -Pk $mount |tail -n 1 )
    # %d floors our values.
    AvailGiB=$(awk "BEGIN{printf \"%d\",($AvailKiB / ( 2^20 ) )}");    
    if [ "$AvailGiB" -lt $minGiB ];then
	#err_m=$(echo -e "${err_m}disk $mount dangerously full!\n");
	err_m+="disk $mount dangerously full!\n";
    fi
done
if [ ! -z "$err_m" ]; then
    printf "$err_m" >&2;
    exit 1; 
fi;
echo "Healthy";
exit 0;
