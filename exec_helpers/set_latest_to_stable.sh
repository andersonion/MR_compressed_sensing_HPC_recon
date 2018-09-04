#!/bin/bash
# set latset to stable, after a matlab compile 
# wouldnt it be great if we saved the last stable set when we were setting a new stable set?
# maybe we can do that using check_stable,
update_count=$($(dirname $0)/check_stable.sh|grep -c 'is not latest');
# followed by a tag_execs with stable -> stable-todaysdate
if [[ $update_count -ge 1 ]]; then
    now=$(date +"%Y%m%d_%H%M%S") 
    echo "Update detected, will copy previous stable to stable-$now";
    $(dirname $0)/tag_execs.sh stable stable-$now 1
fi;
# then follow it up with latest->stable 
$(dirname $0)/tag_execs.sh latest stable 1
exit;
