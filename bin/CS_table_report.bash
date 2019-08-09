#!/bin/bash
# Count the characters 1 and 0 in a file 
# show the sum of those, and the true character count
# warn if there is a discrepancy.
# This was created to help validate CS acq tables in tablib
# James Cook 2019-08-09
if [ -z "$1" ];
then echo "Please specify a table file";
    exit 1; 
fi
t="$1";
if [ ! -f $t ];
then echo "Bad path to file \"$t\"";
    exit 1;
fi;
zeros=$(tr -cd '0' < $t |wc -c )
ones=$(tr -cd '1' < $t | wc -c );
total=$(wc -c $t|cut -d ' ' -f 1);
echo "$t";
printf '\tzeros:\t%i\n' $zeros;
printf '\tOnes:\t%i\n' $ones;
let result="$ones+$zeros";
printf '\tsum 0&1:\t%i\n' $result;
printf '\tTotal:\t%i\n' $total;
if [ "$result" -ne "$total" ];
then echo "WARNING: total($total) is not $result";
    exit 1;
fi;

