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
my $overwrite=$ARGV[2] || 0;

my $parent_path="${bd}/${runno}.work";
my $results_path="${parent_path}/${runno}_recon_times";

if ( -d $parent_path && ! -d ${results_path} ) {
    system("mkdir -m 775 ${results_path}");
}

chdir "${parent_path}";
#for folder in $(ls -d ${runno}_m*); do 
my @runno_things=glob($runno."_m*");
my @runnos;
foreach my $folder ( @runno_things ){
    if ( -f $folder ){ 
	next;
    }
    push(@runnos,$folder);
    print("% collecting $folder\n");
    my $txt_1="$results_path/${folder}_slice_recon_times.txt";
    my $txt_2="$results_path/${folder}_slice_numbers.txt";
    my $txt_3="$results_path/${folder}_iterations.txt";
    if ( ! -f ${txt_1} || $overwrite ) {
	#my $sh_cmd="grep 'Time to rec' ${folder}/*log | cut -d ' ' -f8 > ${txt_1}";
	my $sh_cmd="sed -nr 's/.*Time to rec.*:[ ]*([0-9]+[.][0-9]+)[ ]+.*/\\1/p' ${folder}/*log > ${txt_1}";
	my @out=qx($sh_cmd);# this dumps to the txt file
    }
    if ( ! -f ${txt_2} || $overwrite ) {
	#my $sh_cmd="grep '(\"' ${folder}/*log | cut -d ' ' -f2 | cut -d ':' -f1 > ${txt_2}";
	#my $sh_cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Reconstruction flag.*/\\1/p' ${folder}/*log > ${txt_2}";
	# For some reason we didnt have the right number of written Reconstruction flag lines,
	# so we switched to our time to rec line since that has to match, and iterations done. 
	my $sh_cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Time to rec.*/\\1/p' ${folder}/*log > ${txt_2}";
	my @out=qx($sh_cmd);# this dumps to the txt file
    }
    if ( ! -f ${txt_3} || $overwrite ) {
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
    "slice_min     = zeros(1,numel(runs));\n".
    "slice_max     = zeros(1,numel(runs));\n".
    "for rn=1:numel(runs)\n".
    "    [mean_time(rn), total_time(rn), u_sorted_times{rn}, restarts(rn)] = ...\n".
    "         CS_recon_slice_time_analyzer(results_path, runs{rn}, make_plots);\n".
    "    if numel(u_sorted_times{rn})>0\n".
    "        slice_min(rn)=min(u_sorted_times{rn});\n".
    "        slice_max(rn)=max(u_sorted_times{rn});\n".
    "    end\n".
    "    if make_plots\n".
    "        pause(1);\n".
    "    end\n".
    "end\n".
    "shortest_slice=min(nonzeros(slice_min));\n".
    "longest_slice =max(slice_max);\n".
    "\n\n".
    "%% set the slice count,\n".
    "% i need your slice count now, its not apparent from the data we've gatherd here.\n".
    "% we try to pull it from our recon setup files. \n".
    "% if that fails you can set it manually. .\n".
    "%with \"slice_count=READOUT_DIMENSION\"  ;\n".
    "%% auto guess\n".
    "wkdir=fileparts(results_path);\n".
    "[~,n]=fileparts(wkdir);\n".
    "rx=n;\n".
    "reco_file=fullfile(wkdir,sprintf('%srecon.mat',rx));\n".
    "if exist(reco_file,'file')\n".
    "    reco.(rx)=matfile(reco_file);\n".
    "    slice_count=reco.(rx).dim_x;\n".
    "end".
    "\n\n".
    "%% using slice count tell how long a volume will take with various core counts\n".
    "volume_min_sec=slice_count*shortest_slice;\n".
    "volume_max_sec=slice_count*longest_slice;\n".
    "volume_min_time=datestr(volume_min_sec/86400, 'HH:MM:SS.FFF');\n".
    "volume_max_time=datestr(volume_max_sec/86400, 'HH:MM:SS.FFF');\n".
    "fprintf('Time format is \"HH:MM:SS.FFF\"\\n');\n".
    "fprintf('each volume will take (min) %s - %s (max)\\n',volume_min_time,volume_max_time);\n".
    "warning('THIS IS THE PER CORE TIME, DIVIDE BY THE NUMBER OF CORES YOU WILL USE');\n".
    "warning('THIS DOENST COUNT INEFFICIENCIES IN THE PROCESS DUE TO MATLAB EXECs, or setup/save time');\n".
    #"core_counts=sort([16:16:16*6, 20:20:20*4]); % our real core count in the cluster, not hyperthreaded.\n".
    "c_n1=16:16:16*6; c_n2=20:20:20*4;\n".
    "c_comb=bsxfun(\@plus,c_n1.',c_n2);\n".
    "core_counts=unique([c_n1(:);c_n2(:);c_comb(:)]);% our real core count in the cluster, not hyperthreaded.\n".
    "for cc=1:numel(core_counts)\n".
    "    c=core_counts(cc);\n".
    "    volume_min_time=datestr(volume_min_sec/86400/c, 'HH:MM:SS.FFF');\n".
    "    volume_max_time=datestr(volume_max_sec/86400/c, 'HH:MM:SS.FFF');\n".
    "    fprintf('with %i cores, each volume will take (min) %s - %s (max)\\n',c,volume_min_time,volume_max_time);\n".
    "end\n".
    "";
