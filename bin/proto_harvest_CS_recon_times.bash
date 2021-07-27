#!/bin/bash
#user=cof
bd=/civmnas4/cof/;#Biggus_Diskus-type path
runno=N56079
parent_path=${bd}/{runno}.work;
results_path=${bd}/${runno}.work/${runno}_recon_times
if [ ! -d ${results_path} ]; then
mkdir -m 775 ${results_path};
fi

cd ${parent_path};
for folder in $(ls -d ${runno}_m*); do
txt_1=${results_path}/${folder}_slice_recon_times.txt;
txt_2=${results_path}/${folder}_slice_numbers.txt;
txt_3=${results_path}/${folder}_iterations.txt;
if [ ! -f ${txt_1} ];then
grep Time\ to\ rec ${folder}/*log | cut -d ' ' -f8 > ${txt_1};
fi;

if [ ! -f ${txt_2} ];then
grep "(\"" ${folder}/*log | cut -d ' ' -f2 | cut -d ':' -f1 > ${txt_2};
fi;

if [ ! -f ${txt_3} ];then
grep "(\"" ${folder}/*log | cut -d '"' -f2 > ${txt_3};
fi;
done
