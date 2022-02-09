#!/usr/bin/env perl
# To keep up with ever improving boiler plate ideas, this exists to capture them
# Boilerplate code is rarely updated, but often it's a good idea.
# So this'll exist as a record of the "current standard" maybe, riddled with me
# explaining things to ... me.
#
# Special she-bang finds default perl. This should be correct most the time from here forward.
use strict;
use warnings FATAL => qw(uninitialized);
# carp and friends, backtrace yn, fatal yn
use Carp qw(cluck confess carp croak);
our $DEF_WARN=$SIG{__WARN__};
our $DEF_DIE=$SIG{__DIE__};
# Seems like it'd be great to have this signal handler dependent on debug_val.
# hard to wire that into a general concept.
# compile time issues, but probably fine at runtime.
#$SIG{__WARN__} = sub { cluck "Undef value: @_" if $_[0] =~ /undefined|uninitialized/;&{$DEF_WARN}(@_) };
$SIG{__WARN__} = sub {
    cluck "Undef value: @_" if $_[0] =~ /undefined|uninitialized/;
    #if(defined $DEF_WARN) { &{$DEF_WARN}(@_)}
    if(defined $DEF_WARN) {
        &{$DEF_WARN}(@_);
    } else { warn(@_); }
  };

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
use Headfile;



# DIDN'T WORK
exit 1;
$debug_val=100;
my $ED=load_engine_deps();




my @list=qw(S69242 S69224 S69236 S69232 S69240);
@list=qw(S69238 S69234 S69226 S69224);

require Cwd;
my $startup_dir = Cwd::getcwd();
my @mat_cmds=();
for my $runno (@list){

    my $dir_work = File::Spec->catdir($BIGGUS_DISKUS,"$runno.work","qsm");
    mkdir $dir_work if ! -d $dir_work;
    chdir($dir_work);
    my @__args=($runno);
    my $mat_args="'".join("', '",@__args)."'";
    my $matlab_code="addpath('/cm/shared/workstation_code_dev/recon/CS_v2/prototype/');prototype_qsm_cs_workdir";
    $matlab_code="addpath('/cm/shared/workstation_code_dev/recon/CS_v2/prototype/');disp";
    my $cmd=make_matlab_command_nohf("$matlab_code",$mat_args,$runno."_"
                                     ,$dir_work
                                     ,$ED->get_value("engine_app_matlab")
                                     ,File::Spec->catfile($dir_work,$runno."_qsm_matlab.log")
                                     ,$ED->get_value("engine_app_matlab_opts"), 0);
    push(@mat_cmds,$cmd);
}
$ENV{"SBATCH_MEM"}=0;
$ENV{"SLURM_MEM"}=0;

# THIS FAILS
#execute(1,"qsm batch",@mat_cmds);

# Investigating why the failure, it appears that non-contiguous numbers cause trouble
# auto-array works reasonable, HOWEVER range_condenser cannot condense the range, 
# THEN range_minmax fails to operate as expected!
# The Full fix will involve updateing code in pipeline_utilities::execute
my $reduced_list=cluster_auto_array_cmds(\@mat_cmds);

my @numbers=qw(69242 69224 69236 69232 69240);
@numbers=sort(@numbers);

my $str_range=civm_simple_util::range_condenser(@numbers);
my @rmin_max=civm_simple_util::range_minmax($str_range);
my @rmin_max_T=civm_simple_util::range_minmax("$numbers[0]-$numbers[$#numbers]:2");
Data::Dump::dump([["qsm_proto:",$reduced_list],\@numbers,$str_range,\@rmin_max,\@rmin_max_T]);
