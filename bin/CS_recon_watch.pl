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
use File::Basename;
use Cwd qw(abs_path);
use lib dirname(abs_path($0));


use Headfile;
my $v_ok;
#use slurm::user qw(parse_reservations find_reservations);
my $CSBIN_DIR=dirname(abs_path($0));
my $CSRECON_DIR=dirname($CSBIN_DIR);
my $u_crond=File::Spec->catfile($ENV{"HOME"},'.cron.d');
my $USER=$ENV{"USER"};
# or USER=all to watch all runnos
#$USER='all';


my $opts={};
#${$opts->{"delete"}}="";
#${$opts->{"nodecnt|nodecount|nodes|node|n:i"}}=1;
${$opts->{"check!"}}=1;
$opts->{"u_crond=s"}=\$u_crond;
#${$opts->{"user=s"}}=\$USER;
#${$opts->{"user=s"}}=${\$USER};
# slipping options direct to scalar is slightly different syntax, watchout.
$opts->{"user=s"}=\$USER;
$opts=auto_opt($opts,\@ARGV);

#$Data::Dump::dump($opts);die;
#die $USER;


# Process input, er set mode? enable(default), disable, check only, add 1 runno
# Mode always includes check and clear out complete jobs
my $watch_mode=shift @ARGV;
$watch_mode='enable' if ! defined $watch_mode;
#$watch_mode="disable";
#$debug_val=25;

if($watch_mode !~ /enable|disable|cleanup/) {
    die "$watch_mode not valid enable/disable";
}


# Get extra users to email.
my $conf_path=File::Spec->catfile($CSRECON_DIR,"CS_recon_watch_config.headfile");
my $conf = new Headfile ('ro', $conf_path) or die;
$conf->check() or print "conf check error $conf_path\n";
$conf->read_headfile();

($v_ok,my $coder)=$conf->get_value_check("coder");
$coder="" if !$v_ok;
($v_ok, my $sysadmin)=$conf->get_value_check("sysadmin");
$sysadmin="" if !$v_ok;
($v_ok, my $director)=$conf->get_value_check("director");
$director="" if !$v_ok;
#these are email strings, so comma separated.
# Also, need to lead with comma.
# That requrement comes from how they're used in the template, and could stand revision. 
my $EXTRA_USERS="";
$EXTRA_USERS="$EXTRA_USERS,$coder" if $coder ne "";
$EXTRA_USERS="$EXTRA_USERS,$sysadmin" if $sysadmin ne "";
my $IMG_USERS="";
$IMG_USERS=",$director" if $director ne "";

#RUNNO.cron will be added to this and saved to u_crond to keep track of what we've done. 
my $cron_file_prefix="CS_recon_watch_";

if ( ! -e $u_crond ) {
    printf("would make $u_crond\n");
    mkdir($u_crond);
}


# options enable, disable cleanup.
# shelly code helpers from cs recon used to get the currently operational recons. 
my $cron_template=File::Spec->catfile($CSRECON_DIR,'utility','template_CS_recon_watch_status.cron');
if ( ! -e $cron_template )  {
    die "Missing template $cron_template" unless $mode =~/cleanup/;
}
my $cron_cleanup_template=File::Spec->catfile($CSRECON_DIR,'utility','template_CS_recon_watch_cleanup.cron');
if ( ! -e $cron_cleanup_template )  {
    die "Missing template $cron_cleanup_template";
}
##template_auto_insert.cron
#t_run="runno"
#EXTRA_USERS
#IMG_USERs

=item crontab doc.
Config::Crontab cpan module. though its a bit old and not updated.
    +---------------------------------------------------------+
    |     Config::Crontab object                              |
    |                                                         |
    |  +---------------------------------------------------+  |
    |  |      Config::Crontab::Block object                |  |
    |  |                                                   |  |
    |  |  +---------------------------------------------+  |  |
    |  |  |       Config::Crontab::Env object           |  |  |
    |  |  |                                             |  |  |
    |  |  |  -name => MAILTO                            |  |  |
    |  |  |  -value => joe@schmoe.org                   |  |  |
    |  |  |  -data => MAILTO=joe@schmoe.org             |  |  |
    |  |  +---------------------------------------------+  |  |
    |  +---------------------------------------------------+  |
    |                                                         |
    |  +---------------------------------------------------+  |
    |  |      Config::Crontab::Block object                |  |
    |  |                                                   |  |
    |  |  +---------------------------------------------+  |  |
    |  |  |       Config::Crontab::Comment object       |  |  |
    |  |  |                                             |  |  |
    |  |  |  -data => ## send reminder in April         |  |  |
    |  |  +---------------------------------------------+  |  |
    |  |                                                   |  |
    |  |  +---------------------------------------------+  |  |
    |  |  |       Config::Crontab::Event Object         |  |  |
    |  |  |                                             |  |  |
    |  |  |  -datetime => 3 10 * Apr Fri                |  |  |
    |  |  |  -special => (empty)                        |  |  |
    |  |  |  -minute => 3                               |  |  |
    |  |  |  -hour => 10                                |  |  |
    |  |  |  -dom => *                                  |  |  |
    |  |  |  -month => Apr                              |  |  |
    |  |  |  -dow => Fri                                |  |  |
    |  |  |  -user => joe                               |  |  |
    |  |  |  -command => echo "Friday a.m. in April"    |  |  |
    |  |  +---------------------------------------------+  |  |
    |  +---------------------------------------------------+  |
    +---------------------------------------------------------+
=cut

use Config::Crontab;
if ( 0 ) { 
my $template = new Config::Crontab( -file => $cron_template);
#$template->mode('block');
$template->read or die $template->error;
for my $block ( $template->blocks ) {
    print "---\n";
    print $block->dump;
    print "---\n";
}
#print("set: $set_line\n");
my ($set_line)=$template->select( -type => 'env', 
		   -name_re => 't_run=');
print $set_line->dump ."\n";
}


printd(5,"Getting active runnos ...\n");
my @runnos=run_and_watch("show_running_cs_runnos $USER");
chomp(@runnos);
if(!scalar(@runnos)) {
    printd(5,"No active runnos found to enable, will still check for old ones\n");
}
#Data::Dump::dump(@runnos);


# the user cron
my $ct = new Config::Crontab;
$ct->read;

# a count of our update operations, if > 0 we write our updated crontab
my $update=0;
for (@runnos) {
    # cleanup will neither add nor remove.
    next if $watch_mode =~ /cleanup/x;
    my $r_cron_path =File::Spec->catfile($u_crond,$cron_file_prefix."$_.cron");
    # check if block is already in ct
    my ($r_run)=$ct->select( -type => 'env', 
			     -name_re => 't_run',
			     -value_re => "^$_\$");
    my $block;
    if(defined $r_run) {
	$block=$ct->block($r_run);
	if($watch_mode =~ /enable/x ) {
	    printd(25,"CS_recon_watch previously enabled:$_\n");
	} elsif($watch_mode =~ /disable/x ) {
	    printd(25,"CS_recon_watch disable:$_\n");
	    $ct->remove($block);
	    $update++;
	}
	next;
    }
    next if($watch_mode =~ /disable/x );
    my $cron_file=$cron_template;
    if ( -e $r_cron_path ) {
	$cron_file=$r_cron_path;

    }
    if( ! defined $block) {
	my $cron_stub = new Config::Crontab( -file => $cron_file);
	$cron_stub->read or die $cron_stub->error;
	# env line
	my ($e_l)=$cron_stub->select( -type => 'env', 
				      -name_re => 't_run');
	$e_l->value($_);
	$block=$cron_stub->block($e_l);
	($e_l)=$cron_stub->select( -type => 'env', 
			       -name_re => 'EXTRA_USERS');
	$e_l->value($EXTRA_USERS) if $EXTRA_USERS ne "";
	($e_l)=$cron_stub->select( -type => 'env', 
				   -name_re => 'IMG_USERS');
	$e_l->value($IMG_USERS) if $IMG_USERS ne "";
	$cron_stub->write($r_cron_path);
    }
    printd(25,"CS_recon_watch adding:$_\n");
    $ct->last($block);
    $update++;
}

# get all blocks, if their t_run value is not an active runno remove them
if(${$opts->{"check"}}) {
    my @e_ls=$ct->select( -type =>  'env' , 
			  -name_re => 't_run', 
			  -value_nre => '^'.join('|',@runnos).'$' );
    printd(5,"Cleaning up complete work\n") if scalar(@e_ls);
    foreach (@e_ls) {
	my $block=$ct->block($_);
	printd(25,"Removing cron job non-running".$_->value."\n");
	$ct->remove($block);
	$update++;
    }
}

# cleanup lines
my ($c_l)=$ct->select( -command_re => 'CS_recon_watch.*cleanup');
# active lines indicating we have more cs_recon status calls to work on.
# chose this instead of command becuase this more likly template lines
my @a_ls=$ct->select( -type =>  'env' , 
		      -name_re => 't_run' );
# active lines
#my @a_ls=$ct->select(-command_re => 'status_CS_recon' );
if(scalar(@a_ls)>=1 && ! defined $c_l) {
# some commands found so, we need a cleanup call but we dont have one. 
    my $cron_file=$cron_cleanup_template;
    my $cron_stub = new Config::Crontab( -file => $cron_file);
    $cron_stub->read or die $cron_stub->error;
    my ($e_l)=$cron_stub->select( -command_re => 'CS_recon_watch.*cleanup');
    $e_l->value($_);
    my $block=$cron_stub->block($e_l);
    $ct->last($block);
    $update++;
} elsif(scalar(@a_ls)==0 && defined $c_l) {
    # no commands found, and we have a cleanup call, so lets get rid ofit. 
    my $block=$ct->block($c_l);
    $ct->remove($block);
    $update++;
}
#for
if($update) {
    $ct->write;
}

exit 0;


#### brainstorming mess below
#Data::Dump::dump($ct);

#ex add new entriy ending in _BLOCK_
my $block = new Config::Crontab::Block( -data => <<_BLOCK_ );
## mail something to joe at 5 after midnight on Fridays
MAILTO=joe
5 0 * * Fri /bin/someprogram 2>&1
_BLOCK_

# comment, but not delete a job with re
#    $_->active(0) for $ct->select(-command_re => '/sbin/backup');
# same thing, remove
#    $ct->remove($ct->block($ct->select(-command_re => "/sbin/backup")));
# gotta write when done.
#    $ct->write;


# Plan is, when this runs it gets all running runnos, then it checks for watcher lines already in existence
# have to use runno regex to find runnos we're watching.
# for any are not in the run list, we remove the block. 
# for any are not in the watch list, we add
# 
# need config sysadmin, coder, director, offer them as additional watchers for things Save as default to user dir.


