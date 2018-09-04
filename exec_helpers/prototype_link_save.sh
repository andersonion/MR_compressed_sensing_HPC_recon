#!/bin/bash
exit;
for exec in $(./check_stable.sh|grep -C 1 'not latest'|grep stable:|cut -d ':' -f2-);
do echo $exec;
    # exec date and name, which only work because of how we format the names for our links.
    e_date=$(basename $exec|cut -d '_' -f1);
    e_name=$(basename $(dirname $exec));
    echo ln -s $exec $e_name/stable_20180904-from-${e_date};
done
