%compile me
script_name = 'streaming_CS_recon_main';


matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
master_dir = '/cm/shared/workstation_code_dev/matlab_execs/';
main_dir = [master_dir script_name '_executable/'];
%main_dir = '/nas4/rja20/CS_recon_setup_executable/'
latest_path_link = [main_dir 'latest'];

original_builtin_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
original_builtin_script = 'run_streaming_CS_recon_main_exec_builtin_path.sh';
original_builtin_path=[original_builtin_dir original_builtin_script];
bin_path = '/cm/shared/workstation_code_dev/bin/streaming_CS_recon';


ts=fix(clock);
compile_time=sprintf('%04i%02i%02i_%02i%02i%02i',ts(1:5));

my_dir = [main_dir compile_time '/']

addpath('/cm/shared/workstation_code_dev/recon/CS_v2/');
version = 1;

if (version == 1)
    v_string = '';
elseif (version > 1)
    v_string = ['_v' num2str(version)];
end

mkdir(my_dir)
eval(['!chmod a+rwx ' my_dir])

%source_dir =  '/cm/shared/workstation_code_dev/recon/CS/';
source_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
source_filename = ['streaming_CS_recon_main_exec' v_string '.m'];
source_file = [source_dir source_filename]

include_string =[];
include_files = {'/cm/shared/workstation_code_dev/recon/CS_v2/gui_info_collect.m' ...    
    '/cm/shared/workstation_code_dev/recon/CS_v2/puller_glusterspaceCS_2.m' ...
    '/cm/shared/apps/MATLAB/R2015b/toolbox/signal/signal/hamming.m' ...
    '/cm/shared/apps/MATLAB/R2015b/toolbox/images/images/padarray.m' ...
    '/cm/shared/workstation_code_dev/recon/CS_v2/zpad.m'};

for ff = 1:length(include_files)
    include_string = [include_string ' -a ' include_files{ff} ' '];
    %system(cp_cmd);
end
 %-R -singleCompThread
eval(['mcc -N -d  ' my_dir...
   ' -C -m '...
   ' -R nodisplay -R nosplash -R nojvm '...
   ' ' include_string ' '...
   ' ' source_file ';']) 
   %' -a /home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850/WavePath2.m '...
   %' /home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/CS_recon_cluster_setup_work_exec.m;'])


cp_cmd_2 = ['cp  ' source_file ' ' my_dir];
system(cp_cmd_2)
for ff = 1:length(include_files)
    cp_cmd = ['cp ' include_files{ff} ' ' my_dir];
    system(cp_cmd);
end
%
%    -a /cm/shared/workstation_code_dev/recon/mat_recon_pipe/filter/fermi/fermi_filter_isodim2_memfix.m ...
first_run_cmd = [my_dir '/run_' source_filename];
first_run_cmd(end)=[];
first_run_cmd = [first_run_cmd 'sh ' matlab_path];
system(first_run_cmd);


eval(['!chmod a+rwx -R ' my_dir '/*'])


if exist(latest_path_link,'dir')
    rm_ln_cmd = sprintf('rm %s',latest_path_link);
    system(rm_ln_cmd)
end

ln_cmd = sprintf('ln -s %s %s',my_dir,latest_path_link);
system(ln_cmd);

update_bin_cmd=sprintf('cp %s %s/;rm %s;ln -s %s/%s %s',original_builtin_path,my_dir,bin_path,my_dir,original_builtin_script,bin_path)
system(update_bin_cmd);