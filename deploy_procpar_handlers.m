function [ c_running_jobs ] = deploy_procpar_handlers(setup_variables)
% Handles waiting for the procpar file to exist,
% then processing it into a complete headfile.
 
%% OPAQUE LOAD OF A BUNCH OF THINGS
% load(setup_variables)
setup_var=matfile(setup_variables);
recon_mat=matfile(setup_var.recon_file);
options=recon_mat.options;
try 
    recon_type=recon_mat.recon_type;
catch
    recon_type = 'CS_v2';
    warning('Default recon type: %s',recon_type);
end
%%%%%%

%%
hf_fail_flag=    fullfile(setup_var.images_dir,...
    sprintf('.%s_send_headfile_to_%s_FAILED',setup_var.volume_runno, options.target_machine));
hf_success_flag= fullfile(setup_var.images_dir,...
    sprintf('.%s_send_headfile_to_%s_SUCCESSFUL',setup_var.volume_runno, options.target_machine));


target_host_name=sprintf('%s.dhe.duke.edu',options.target_machine);

matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
cs_queue=CS_env_queue();
%% exec path setting
% set an env var to get latest dev code, or will defacto run stable.
cs_execs=CS_env_execs();

%%
% Send a message that all recon is completed and has successfully
% been sent to the target machine
%% build shell commnands that do work.
% if fail flag exists, remove it.
%{
ship_cmd_0=sprintf([...
    'if [[ -f %s ]]; then\n' ...
    '\t  rm %s;\nfi'], ...
    hf_fail_flag,hf_fail_flag);
%}
if ~exist('USE_OLD_REMOTE_CHECK_CODE','var')
    cmd_stack={};
    ssh_dest=sprintf('%s@%s',getenv('USER'),  target_host_name);
    % complex remote checks are brittle, so we dont want to do that.
    % We're going to cheese things slightly, and run a remote mkdir without
    % checking for success.
    
    cmd_stack{end+1}=sprintf('hff="%s";',hf_fail_flag);
    cmd_stack{end+1}=sprintf('hfs="%s";',hf_success_flag);
    cmd_stack{end+1}=sprintf('touch "$hff";');
    % mkdir
    % remote cmd
    % sprintf('mkdir /volumes/%sspace/%s/',options.target_machine,  setup_var.volume_runno)
    mkdir_cmd=sprintf('mkdir -p /volumes/%sspace/%s/%simages/',options.target_machine,  setup_var.volume_runno,  setup_var.volume_runno);
    % local_cmd
    cmd_stack{end+1}=sprintf('ssh %s "%s"',ssh_dest,mkdir_cmd);
    
    % send procpar... But why are we even bothering to send it? Its not
    % part of anything relevant...
    % You know what. We're skipping this now :p
    % local cmd
    %{
    cmd_stack{end+1}=sprintf('scp -p %s %s:/Volumes/%sspace/%s/ || exit 1;',...
        recon_mat.procpar_file, ssh_dest,...
        options.target_machine,  setup_var.volume_runno);
    %}
    % local_cmd
    cmd_stack{end+1}=sprintf('scp -p "%s" "%s:/Volumes/%sspace/%s/%simages/" || exit 1;',...
        setup_var.headfile,  ssh_dest,...
        options.target_machine,  setup_var.volume_runno,  setup_var.volume_runno);
    cmd_stack{end+1}=setup_var.handle_archive_tag_cmd;
    cmd_stack{end+1}=sprintf('touch "$hfs" && rm "$hff"');
    shell_cmds=cmd_stack;
    clear compound_cmd cmd_stack ssh_dest;
else
%WARNING: Cant really neaten these commands up the way they're written
%because newlines interfear with ssh run. EXcept Maybe THeY DOnT BeCaUSE
%wE'Re RUNninG iN SbATch!
% if remote directory missing, create it
ship_prep_send_procpar = sprintf( [ ...
    'ssh %s@%s ''if [[ ! -d /Volumes/%sspace/%s/ ]] ; then'...
    '\t  mkdir /Volumes/%sspace/%s/;'...
    'fi'';'...
    'scp -p %s %s@%s:/Volumes/%sspace/%s/;'],...
    getenv('USER'),  target_host_name,  options.target_machine,  setup_var.volume_runno,...
    options.target_machine,  setup_var.volume_runno,...
    recon_mat.procpar_file,  getenv('USER'),  target_host_name,  options.target_machine,  setup_var.volume_runno);
% if remote images dir missing, create it.
% then send the headfile along
ship_prep_send_headfile = sprintf([ ...
    'hf_success=0;\n'...
    'ssh %s@%s ''if [[ ! -d /Volumes/%sspace/%s/%simages/ ]] ; then'...
    '\t  mkdir /Volumes/%sspace/%s/%simages/;'...
    'fi'';'...
    'scp -p %s %s@%s:/Volumes/%sspace/%s/%simages/ && hf_success=1'],...
    getenv('USER'),  target_host_name,  options.target_machine,  setup_var.volume_runno,  setup_var.volume_runno,...
    options.target_machine,  setup_var.volume_runno,  setup_var.volume_runno,...
    setup_var.headfile,  getenv('USER'),  target_host_name,  options.target_machine, setup_var.volume_runno, setup_var.volume_runno);
% if scp status return good, set hf success flag, else set fail
write_hf_success_cmd = sprintf([...
    'if [[ $hf_success -eq 1 ]];\n'...
    'then\n'...
    '\t  echo "Headfile transfer successful!"\n'...
    '\t  touch %s;\n'...
    'else\n'...
    '\t  touch %s; \n'...
    'fi'],hf_success_flag,hf_fail_flag);
shell_cmds={ ship_prep_send_procpar ship_prep_send_headfile write_hf_success_cmd setup_var.handle_archive_tag_cmd};
end

%% check current acq status
% get procpar file if its missing, and we can.
%pp_running_jobs='';
[~, local_or_streaming_or_static]=find_input_fidCS(recon_mat.scanner,  ...
    recon_mat.runno,  recon_mat.agilent_study,  recon_mat.agilent_series);
if ~exist(recon_mat.procpar_file,'file') ...
        && ( local_or_streaming_or_static ~= 2 ) % && ( (volume_number == n_volumes) || local_or_streaming_or_static ~= 2 )
    mode =2; % Only pull procpar file
    datapath=fullfile('/home/mrraw',recon_mat.agilent_study,[recon_mat.agilent_series '.fid']);
    puller_glusterspaceCS_2(recon_mat.runno,  datapath,  recon_mat.scanner,...
        study_workdir,  mode);
end

%% set up procpar gatekeeper
% uses singleton to hold the next job behind it.
if (~exist(recon_mat.procpar_file,'file') || ~exist(setup_var.headfile,'file'))
    gk_slurm_options=struct;
    gk_slurm_options.v=''; % verbose
    gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
    gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount--or so I thought!.
    gk_slurm_options.p=cs_queue.gatekeeper;
    %gk_slurm_options.job_name = [volume_runno '_procpar_gatekeeper'];
    gk_slurm_options.job_name = [runno '_procpar_gatekeeper_and_processor'];
    %gk_slurm_options.reservation = active_reservation;
    % using a blank reservation to force no reservation for this job.
    gk_slurm_options.reservation = '';
    procpar_gatekeeper_batch = [workdir '/sbatch/' volume_runno '_procpar_gatekeeper.bash'];
    procpar_gatekeeper_args= sprintf('%s %s',[procpar_file ':' headfile],log_file);
    procpar_gatekeeper_cmd = sprintf('%s %s %s', cs_execs.procpar_gatekeeper, matlab_path,procpar_gatekeeper_args);
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
ppcu_slurm_options.job_name = [recon_mat.runno '_procpar_gatekeeper_and_processor']; % Trying singleton dependency
%ppcu_slurm_options.reservation = active_reservation;
% using a blank reservation to force no reservation for this job.
ppcu_slurm_options.reservation = '';
procpar_cleanup_batch = fullfile(setup_var.workdir,'sbatch', [setup_var.volume_runno '_procpar_cleanup.bash']);
ppcu_args=sprintf('%s %s %s %s',setup_var.recon_file,  setup_var.headfile,  recon_mat.procpar_file,  recon_type);
ppcu_cmd = sprintf('%s %s %s', cs_execs.procpar_cleanup,  matlab_path, ppcu_args);
dep_string ='';
%if pp_running_jobs
%   dep_string = 'afterok';
%end

% 2018-09-28 its not clear the keep_work setting should have an effect
% here. the if has been disabled. --james
%if ~options.keep_work
if options.live_run
    % in live run we run ppcu internally so blank that before the sbatch
    % this lets our shell cmds run nearly the same way
    ppcu_cmd='';
end
batch_file = create_slurm_batch_files(procpar_cleanup_batch,[ppcu_cmd shell_cmds],ppcu_slurm_options);
if ~options.live_run
    c_running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
else
    eval(sprintf('process_headfile_CS %s',ppcu_args));
    [s,sout]=system(sprintf('bash %s',batch_file));
    if s~=0
        error(sout);
    end
    %{
    for cn=1:numel(shell_cmds)
        [s,sout]=ssh_call(shell_cmds{cn});
        [s,sout]=system(sprintf('bash ''%s''',shell_cmds{cn}),'-echo');
        if s~=0
            error('failed! %s \n with output\n%s',shell_cmds{cn},sout);
        end
    end
    %}
    c_running_jobs='';
end
