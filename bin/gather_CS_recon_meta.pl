#!/usr/bin/env perl
# To keep up with ever improving boiler plate ideas, this exists to capture them
# Boilerplate code is rarely updated, but often it's a good idea.
# So this'll exist as a record of the "current standard" maybe, riddled with me
# explaining things to ... me.
#
# Special sha-bang finds default perl. This should be correct most the time from here forward.
use strict;
use warnings;

#### VAR CHECK
# Note, vars will have to be hardcoded becuased this is a check for env.
# That means, ONLY variables which will certainly exist should be here.
# BOILER PLATE
BEGIN {
    # we could import radish_perl_lib direct to an array, however that complicates the if def checking.
    my @env_vars=qw(RADISH_PERL_LIB BIGGUS_DISKUS WORKSTATION_DATA WORKSTATION_HOME);
    my @errors;
    use Env @env_vars;
    foreach (@env_vars ) {
        push(@errors,"ENV missing: $_") if (! defined(eval("\$$_")) );
    }
    die "Setup incomplete:\n\t".join("\n\t",@errors)."\n  quitting.\n" if @errors;
}
use lib split(':',$RADISH_PERL_LIB);
# my absolute fav civm_simple_util components.
use civm_simple_util qw(activity_log printd $debug_val);
# On the fence about including pipe utils every time
use pipeline_utilities;
# pipeline_utilities uses GOODEXIT and BADEXIT, but it doesnt choose for you which you want.
$GOODEXIT = 0;
$BADEXIT  = 1;
# END BOILER PLATE
$debug_val=20;
use civm_simple_util qw($num_ex load_file_to_array write_array_to_file);

# based on the prototype code harvest_CS_recon_times.bash

if ( scalar(@ARGV) < 1 ) {
    die('please specify runno on your scratch space, and optionally an alternate scratch space.');
}

my $runno=$ARGV[0];
my $bd=$ARGV[1] || $ENV{'BIGGUS_DISKUS'};
my $overwrite=$ARGV[2] || 0;

my $parent_path="${bd}/${runno}.work";
my $results_path="${parent_path}/${runno}_recon_times";

if ( -d $parent_path && ! -d ${results_path} ) {
    system("mkdir ${results_path}");
}

chdir "${parent_path}";
#for folder in $(ls -d ${runno}_m*); do
my @runno_things=glob($runno."_m*");
my @runnos;


foreach my $folder ( @runno_things ){
    my $slice_db={};
    my $slice_fails={};
# slice db will be a hash of hashes, primary key on slice number.
#
# ex,
# slice_db->{1}->{time_slice}=120.132; # seconds
# slice_db->{1}->{iterations}=400; # equivalent to itnlim
# slice_db->{1}->{time_load}=5.4; # seconds
    if ( -f $folder ){
        next;
    }
    push(@runnos,$folder);
    print("% collecting $folder\n");
    my ($cmd,@in_f,@out);
    @in_f=glob("${folder}/*log");
    if(! scalar(@in_f)) {
        printd(15,"%  No log\n");
        next;
    }elsif( scalar(@in_f)>1) {
        die "error('Mutiple logs found, bailing %s', $folder)";
    }
    my @logA;
    load_file_to_array($in_f[0],\@logA);
    for my $line (@logA){
        chomp($line);
        #$cmd="sed -nr 's/.*Time to rec.*:[ ]*([0-9]+[.][0-9]+)[ ]+.*/\\1/p' ${folder}/*log > ${txt_T}";
        #$cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Time to rec.*/\\1/p' ${folder}/*log > ${txt_N}";*
        #$cmd="sed -nr 's/.*Reconstruction flag [(][\"](.*)[\"][)].*/\\1/p' ${folder}/*log > ${txt_I}";

        # Works for slice time to reconstruct, but cant tell on flag
        my ($N,$T,$V,$TRAIL,$K);
        if ($line =~ m/time\s to\s recon[a-z]*\s data/ix) {
            #print("Time\n");
            ($N,$T,$V,$TRAIL) = $line=~m/^Slice\s+([0-9]+)\s* [:] \s+
              (?: (time\sto\srec[a-z]+[^:]+)[:]
              \s+ ($num_ex) \s seconds[.]
              )
                  (.*?)$/ix;
            $K="time_recon";
        } elsif ($line =~ m/time\s to\s load\s sparse\s data/ix) {
            #print("Time\n");
            ($N,$T,$V,$TRAIL) = $line=~m/^Slice\s+([0-9]+)\s* [:] \s+
              (?: (time\sto\sload\ssparse\sdata)\s*[:]
              \s+ ($num_ex) \s seconds[.]
              )
                  (.*?)$/ix;
            $K="time_load";
        }  elsif ($line =~ m/time\s to\s set\s up\s recon/ix) {
            #print("Time\n");
            ($N,$T,$V,$TRAIL) = $line=~m/^Slice\s+([0-9]+)\s* [:] \s+
              (?: (time\s to\s set\s up\s recon)\s*[:]
              \s+ ($num_ex) \s seconds[.]
              )
                  (.*?)$/ix;
            $K="time_setup";
        }  elsif ($line =~ m/(recon[a-z]+\sflag)/ix) {
            #print("flag\n");
            ($N,$T,$V,$TRAIL) = $line=~m/^Slice\s+([0-9]+)\s* : \s+
                 (recon[a-z]+\sflag)
                  [^"]+["]($num_ex)["]
                 (.*)$/ix;
            $K="iterations";
        } else {
            next;
        }


=item
        $line=~m/^Slice\s+([0-9]+)\s* : \s+
              (?: (time\sto\srec[a-z]+[^:]+):
              \s+ ($num_ex) \s seconds[.]
            )|(?: (recon[a-z]+\sflag)
                  [^"]+["]($num_ex)["]
               )
               (.*?)$/ix;
=cut

=item


        $line=~m/^Slice\s+([0-9]+)\s* : \s+
              (?: (recon[a-z]+\sflag)
                  [^"]+["]($num_ex)["]
               )
               (.*?)$/ix;


        $line=~m/^Slice\s+([0-9]+)\s* [:] \s+ (?:
              (?: (recon[a-z]+\sflag)
                  [^"]+["]($num_ex)["]
              )
               |
              (?: (time\sto\srec[a-z]+[^:]+)[:]
              \s+ ($num_ex) \s+ seconds[.]
              )  )
              (.*?)$/ix;
=cut

        #$line=~m/^Slice\s+([0-9]+)\s* : \s+
        #     (?: (recon[a-z]+\sflag)[^"]+["]($num_ex)["])
        #      (.*)/ix;

        #$line=~m/^Slice\s+([0-9]+)\s* : \s+
        #     (?: (recon[a-z]+\sflag))(.)
        #      (.*)/ix;

        #$line=~m/^Slice\s+([0-9]+)\s*:
        #      (?:\s+ (time\sto\srec[a-z]+[^:]+):
        #      \s+ ($num_ex) \s seconds[.]
        #      (.*))/ix;
        #$line=~m/^Slice\s+([0-9]+)\s*:
        #      \s+ (time\sto\srec[a-z]+[^:]+)
        #z     .*/ix;
        #$line=~m/^(Slice\s+.*)$/ix;
        if(defined $N){
            # noticed one slice with no recon time
            # inserted stop here for debuggy.
            #if($N !~ /1031/x) {
            #next;
            #}
        #if( defined $N){ printf("S:($N)\t($V)\t($T) TRAILING  ($TRAIL) n$num_ex\n");die; }
        #if( defined $N){ printf("S:($N)\t($V)\t($T)\n");die;}
            #printf("S:($N)\t($V)\t($T)\n");
        #printf("$line\nS:($N)\t($V)\t($T) TRAILING  ($TRAIL)\n") if defined $N && defined $V;
            if(!exists $slice_db->{$N}){
                $slice_db->{$N}={};
                $slice_db->{$N}->{"attempts"}=1;
            }
            if(!exists $slice_db->{$N}->{$K}) {
                $slice_db->{$N}->{$K}=[$V];
            } else {
                print("% shunting previous $N to fails\n");
                my $r=$slice_db->{$N};
                my %h=%$r;
                if(!exists $slice_fails->{$N}){
                    $slice_fails->{$N}=[];
                }
                push(@{$slice_fails->{$N}},\%h);
                delete $slice_db->{$N};
                $slice_db->{$N}->{$K}=[$V];
                $slice_db->{$N}->{"attempts"}=$h{"attempts"}+1;
            }

        #printf("$line\nS:($N)\t($V)\t($T) TRAILING  ($TRAIL)\n") if defined $N;
        }
    }
    #Data::Dump::dump($slice_db);die;
    my @nums=sort { $a <=> $b } keys($slice_db);
    #my @out;
    push(@out,sprintf("Slice\tLoad\tSetup\tRecon\tIterations\tAttempts\n"));
    for my $Slice (@nums) {
# HIDDEN DETAIL, setup time includes load time,
        # would subtract it here, but its not always defined.
        #my $attempts=scalar(@$Load);
        my $attempts=$slice_db->{$Slice}->{"attempts"};
        for(my $i=0;$i<1;$i++){
            my $Load=$slice_db->{$Slice}->{"time_load"}->[$i];
            my $Setup=$slice_db->{$Slice}->{"time_setup"}->[$i];
            my $Recon=$slice_db->{$Slice}->{"time_recon"}->[$i];
            my $Iterations=$slice_db->{$Slice}->{"iterations"}->[$i];
            $Load="" if! defined $Load;
            $Setup="" if! defined $Setup;
            $Recon="" if! defined $Recon;
            $Iterations="" if! defined $Iterations;
            push(@out,sprintf("$Slice\t$Load\t$Setup\t$Recon\t$Iterations\t$attempts\n"));
        }
    }
    my $txt_out="$results_path/${folder}_timing.csv";
    write_array_to_file($txt_out,\@out);
    Data::Dump::dump(\@out,$slice_fails);

=item incomplete patternaly bits
    my $txt_T="$results_path/${folder}_slice_recon_times.txt";
    my $txt_N="$results_path/${folder}_slice_numbers.txt";
    my $txt_I="$results_path/${folder}_iterations.txt";
    #if ( ! -f ${txt_T} || $overwrite ) {
    #   #my $sh_cmd="grep 'Time to rec' ${folder}/*log | cut -d ' ' -f8 > ${txt_T}";
    #   my $sh_cmd="sed -nr 's/.*Time to rec.*:[ ]*([0-9]+[.][0-9]+)[ ]+.*/\\1/p' ${folder}/*log > ${txt_T}";
    #   my @out=qx($sh_cmd);# this dumps to the txt file
    #}
    $cmd="sed -nr 's/.*Time to rec.*:[ ]*([0-9]+[.][0-9]+)[ ]+.*/\\1/p' ${folder}/*log > ${txt_T}";
    @out=run_on_update($cmd,\@in_f,[$txt_T]);
    #if ( ! -f ${txt_2} || $overwrite ) {
    #    #my $sh_cmd="grep '(\"' ${folder}/*log | cut -d ' ' -f2 | cut -d ':' -f1 > ${txt_2}";
    #    #my $sh_cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Reconstruction flag.*/\\1/p' ${folder}/*log > ${txt_2}"#;
    #    # For some reason we didnt have the right number of written Reconstruction flag lines,
    #    # so we switched to our time to rec line since that has to match, and iterations done.
    #    my $sh_cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Time to rec.*/\\1/p' ${folder}/*log > ${txt_2}";
    #    my @out=qx($sh_cmd);# this dumps to the txt file
    #}
    $cmd="sed -nr 's/Slice[ ]+([0-9]+)[ ]*:[ ]+Time to rec.*/\\1/p' ${folder}/*log > ${txt_N}";
    @out=run_on_update($cmd,\@in_f,[$txt_N]);
    #if ( ! -f ${txt_3} || $overwrite ) {
    #    #my $sh_cmd="grep '(\"' ${folder}/*log | cut -d '\"' -f2 > ${txt_3}";
    #    my $sh_cmd="sed -nr 's/.*Reconstruction flag [(][\"](.*)[\"][)].*/\\1/p' ${folder}/*log > ${txt_3}";
    #    my @out=qx($sh_cmd);# this dumps to the txt file
    #}
    $cmd="sed -nr 's/.*Reconstruction flag [(][\"](.*)[\"][)].*/\\1/p' ${folder}/*log > ${txt_I}";
    @out=run_on_update($cmd,\@in_f,[$txt_I]);
=cut
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
