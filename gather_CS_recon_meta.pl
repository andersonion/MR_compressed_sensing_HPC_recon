#!/usr/bin/perl
# mimialist data collector for cs_recon time calculating
# based on the prototype code harvest_CS_recon_times.bash

use strict;
use warnings;

if(  ! exists $ENV{'BIGGUS_DISKUS'} ) { 
    die('BIGGUS_DISKUS unset! not sure what to do.');
}

if ( scalar(@ARGV) < 1 ) {
    die('please specify runno on your scratch space, and optionally an alternate scratch space.');
}

my $runno=$ARGV[0];
my $bd=$ARGV[1] || $ENV{'BIGGUS_DISKUS'};

my $parent_path="${bd}/${runno}.work";
my $results_path="${parent_path}/${runno}_recon_times";

if ( -d $parent_path && ! -d ${results_path} ) {
    system("mkdir -m 775 ${results_path}");
}

chdir "${parent_path}";
#for folder in $(ls -d ${runno}_m*); do 
my @runnos=glob($runno."_m*");
foreach my $folder ( @runnos ){
    print("dumping $folder\n");
    my $txt_1="$results_path/${folder}_slice_recon_times.txt";
    my $txt_2="$results_path/${folder}_slice_numbers.txt";
    my $txt_3="$results_path/${folder}_iterations.txt";
    if ( ! -f ${txt_1} ) {
	#my $sh_cmd="grep 'Time to rec' ${folder}/*log | cut -d ' ' -f8 > ${txt_1}";
	my $sh_cmd="sed -nr 's/.*Time to rec.*:[ ]*([0-9]+[.][0-9]+)[ ]+.*/\\1/p' ${folder}/*log > ${txt_1}";
	my @out=qx($sh_cmd);# this dumps to the txt file
    }
    if ( ! -f ${txt_2} ) {
	#my $sh_cmd="grep '(\"' ${folder}/*log | cut -d ' ' -f2 | cut -d ':' -f1 > ${txt_2}";
	#my $sh_cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Reconstruction flag.*/\\1/p' ${folder}/*log > ${txt_2}";
	# For some reason we didnt have the right number of written Reconstruction flag lines,
	# so we switched to our time to rec line since that has to match, and iterations done. 
	my $sh_cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Time to rec.*/\\1/p' ${folder}/*log > ${txt_2}";
	my @out=qx($sh_cmd);# this dumps to the txt file
    }
    if ( ! -f ${txt_3} ) {
	#my $sh_cmd="grep '(\"' ${folder}/*log | cut -d '\"' -f2 > ${txt_3}";
	my $sh_cmd="sed -nr 's/.*Reconstruction flag [(][\"](.*)[\"][)].*/\\1/p' ${folder}/*log > ${txt_3}";
	my @out=qx($sh_cmd);# this dumps to the txt file
    }
}


#[mean_time, total_time, u_sorted_times, restarts]=CS_recon_slice_time_analyzer(results_path, volume_no, make_plots)
print "\n\n%% You can finish the analysis in matlab now using \n".
    "% copy and paste code right into matlab for great fun!\n".
    "results_path='$results_path';\n".
    "make_plots=0;% or you can set it to 1 for funsies\n".
    "runs={'",join('\',\'',@runnos)."'};\n".
    "mean_time     = zeros(1,numel(runs));\n".
    "total_time    = zeros(1,numel(runs));\n".
    "u_sorted_times= cell(1,numel(runs));\n".
    "restarts      = zeros(1,numel(runs));\n".
    "for rn=1:numel(runs)\n".
    "    [mean_time(rn), total_time(rn), u_sorted_times{rn}, restarts(rn)] = ...\n".
    "         CS_recon_slice_time_analyzer(results_path, runs{rn}, make_plots);\n".
    "    if make_plots\n".
    "        pause(1);\n".
    "    end\n".
    "end\n";



