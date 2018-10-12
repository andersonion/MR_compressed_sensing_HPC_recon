function [ c_running_jobs ] = deploy_procpar_handlers(volume_variable_file)
% Handles waiting for the procpar file to exist,
% then processing it into a complete headfile.
 
% TEMPORARY CODE for backwards compatibility of in-progress scans remove by
% June 12th, 2018
%{
if ~exist(volume_variable_file,'file')
    [t_workdir, t_file_name, t_ext]=fileparts(volume_variable_file);
    old_vv_file = [t_workdir '/work/' t_file_name t_ext];
    mv_cmd = ['mv ' old_vv_file ' ' volume_variable_file];
    if exist(old_vv_file,'file')
        system(mv_cmd);
    end
end
%}
%% OPAQUE LOAD OF A BUNCH OF THINGS
load(volume_variable_file)
%%%%%%

%%

hf_fail_flag=         sprintf('%s/.%s_send_headfile_to_%s_FAILED', ...
    images_dir,volume_runno,target_machine);
hf_success_flag=      sprintf('%s/.%s_send_headfile_to_%s_SUCCESSFUL', ...
    images_dir,volume_runno,target_machine);

full_host_name=sprintf('%s.dhe.duke.edu',target_machine);

recon_type = 'CS_v2';
matlab_path = '/cm/shared/apps/MATLAB/R2015b/';

gatekeeper_queue = getenv('CS_GATEKEEPER_QUEUE');
if isempty(gatekeeper_queue)
    gatekeeper_queue = 'slow_master';%'high_priority';
end
%% exec path setting
% set an env var to get latest dev code, or will defacto run stable.
CS_CODE_DEV=getenv('CS_CODE_DEV');
if isempty(CS_CODE_DEV)
    CS_CODE_DEV='stable';
end
procpar_gatekeeper_exec_path = getenv('CS_PROCPAR_GATEKEEPER_EXEC'); 
if isempty(procpar_gatekeeper_exec_path)
    procpar_gatekeeper_exec_path =['/cm/shared/workstation_code_dev/matlab_execs/local_file_gatekeeper_executable/' CS_CODE_DEV '/run_local_file_gatekeeper_exec.sh'];
    setenv('CS_PROCPAR_GATEKEEPER_EXEC',procpar_gatekeeper_exec_path);
end
procpar_cleanup_exec_path = getenv('CS_PROCPAR_CLEANUP_EXEC');
if isempty(procpar_cleanup_exec_path)
    procpar_cleanup_exec_path=['/cm/shared/workstation_code_dev/matlab_execs/process_headfile_CS_executable/' CS_CODE_DEV '/run_process_headfile_CS.sh'];
    setenv('CS_PROCPAR_CLEANUP_EXEC',procpar_cleanup_exec_path);
end

%%
% Send a message that all recon is completed and has successfully
% been sent to the target machine
%% build shell commnands that do work.
ship_cmd_0=sprintf('if [[ -f %s ]]; then\n\trm %s;\nfi',hf_fail_flag,hf_fail_flag);
ship_cmd_1 = sprintf(['ssh %s@%s ''if [[ ! -d /Volumes/%sspace/%s/ ]] ; then\n'...
    '\t mkdir -m 777 /Volumes/%sspace/%s/;\n'...
    'fi;''\n'...
    'scp -p %s %s@%s:/Volumes/%sspace/%s/;'],...
    getenv('USER'),full_host_name,target_machine,volume_runno,target_machine,volume_runno,...
    procpar_file,getenv('USER'),full_host_name,target_machine,volume_runno);
ship_cmd_2 = sprintf(['hf_success=0;\n'...
    'ssh %s@%s ''if [[ ! -d /Volumes/%sspace/%s/%simages/ ]] ; then\n'...
    '\t mkdir -m 777 /Volumes/%sspace/%s/%simages/;\n'...
    'fi '';\n'...
    'scp -p %s %s@%s:/Volumes/%sspace/%s/%simages/ && hf_success=1'],...
    getenv('USER'),full_host_name,target_machine,volume_runno,volume_runno,target_machine,volume_runno, volume_runno,...
    headfile,getenv('USER'),full_host_name,target_machine,volume_runno,volume_runno);
write_hf_success_cmd = sprintf(['if [[ $hf_success -eq 1 ]];\n'...
    'then\n'...
    '\techo "Headfile transfer successful!"\n'...
    '\ttouch %s;\n'...
    'else\n'...
    '\ttouch %s; \n'...
    'fi'],hf_success_flag,hf_fail_flag);

%% check current acq status
% get procpar file if its missing, and we can.
%pp_running_jobs='';
[~, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
if ~exist(procpar_file,'file') ...
        && ( local_or_streaming_or_static ~= 2 ) % && ( (volume_number == n_volumes) || local_or_streaming_or_static ~= 2 )
    mode =2; % Only pull procpar file
    datapath=fullfile('/home/mrraw',study,[agilent_series '.fid']);
    puller_glusterspaceCS_2(runno,datapath,scanner,study_workdir,mode);
end

%% set up procpar gatekeeper
% uses singleton to hold the next job behind it.
if (~exist(procpar_file,'file') || ~exist(headfile,'file'))
    gk_slurm_options=struct;
    gk_slurm_options.v=''; % verbose
    gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
    gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount--or so I thought!.
    gk_slurm_options.p=gatekeeper_queue;
    %gk_slurm_options.job_name = [volume_runno '_procpar_gatekeeper'];
    gk_slurm_options.job_name = [runno '_procpar_gatekeeper_and_processor'];
    %gk_slurm_options.reservation = active_reservation;
    % using a blank reservation to force no reservation for this job.
    gk_slurm_options.reservation = '';
    procpar_gatekeeper_batch = [workdir '/sbatch/' volume_runno '_procpar_gatekeeper.bash'];
    procpar_gatekeeper_args= sprintf('%s %s',[procpar_file ':' headfile],log_file);
    procpar_gatekeeper_cmd = sprintf('%s %s %s', procpar_gatekeeper_exec_path, matlab_path,procpar_gatekeeper_args);
    if ~options.live_run
        batch_file = create_slurm_batch_files(procpar_gatekeeper_batch,procpar_gatekeeper_cmd,gk_slurm_options);
        pp_running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
        log_mode = 1;
        log_msg =sprintf('Procpar data and/or headfile for volume %s will be processed as soon as it is available; initializing gatekeeper (SLURM jobid(s): %s).\n',volume_runno,pp_running_jobs);
        yet_another_logger(log_msg,log_mode,log_file);
    else
        eval(sprintf('local_file_gatekeeper_exec %s',procpar_gatekeeper_args));
    end
end
%% 
ppcu_slurm_options=struct;
ppcu_slurm_options.v=''; % verbose
ppcu_slurm_options.s=''; % shared; 
ppcu_slurm_options.mem=500; % memory requested; ppcu only needs a miniscule amount.
ppcu_slurm_options.p='slow_master'; % For now, will use gatekeeper queue 
%ppcu_slurm_options.job_name = [volume_runno '_procpar_cleanup'];
ppcu_slurm_options.job_name = [runno '_procpar_gatekeeper_and_processor']; % Trying singleton dependency
%ppcu_slurm_options.reservation = active_reservation;
% using a blank reservation to force no reservation for this job.
ppcu_slurm_options.reservation = '';
procpar_cleanup_batch = [workdir 'sbatch/' volume_runno '_procpar_cleanup.bash'];
ppcu_args=sprintf('%s %s %s %s',recon_file,headfile,procpar_file,recon_type);
ppcu_cmd = sprintf('%s %s %s', procpar_cleanup_exec_path,matlab_path, ppcu_args);
dep_string ='';
%if pp_running_jobs
%   dep_string = 'afterok';
%end

shell_cmds={ship_cmd_0 ship_cmd_1 ship_cmd_2 write_hf_success_cmd handle_archive_tag_cmd};
% 2018-09-28 its not clear the keep_work setting should have an effect
% here. the if has been disabled. --james
%if ~options.keep_work
if ~options.live_run
    batch_file = create_slurm_batch_files(procpar_cleanup_batch,[ppcu_cmd shell_cmds],ppcu_slurm_options);
    c_running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
else
    eval(sprintf('process_headfile_CS %s',ppcu_args));
    for cn=1:numel(shell_cmds)
        [s,sout]=system(sprintf('bash %s',shell_cmds{cn}),'-echo');
        if s~=0
            error('failed! %s \n with output\n%s',shell_cmds{cn},sout);
        end
    end
    c_running_jobs='';
end
