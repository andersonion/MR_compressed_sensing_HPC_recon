function starting_point = volume_manager_exec(recon_file,volume_runno, volume_number,base_workdir)
% Manages the  compressed sensing reconstruction of an independent 3D volume
% % Functions similarly to old code CS_recon_cluster_bj_multithread_v2[a]
%
%
% Written by BJ Anderson, CIVM
% 21 September 2017
 

% for all execs run this little bit of code which prints start and stop time using magic.
C___=exec_startup();

%%% ORIGINAL COMMENT
% This may seem stupid, but I need to let Matlab know that I'm going need
% series to be a variable, and not the builtin function 'series'
%%%%f
% In fact this is stupid, overloading code generates incredible
% headaches.The variale has been renamed agilent_series. -James.
agilent_series='';
workdir=[base_workdir '/' volume_runno '/'];
% Need to figure out how to pass reconfile, scale_file --> just use recon_file!
load(recon_file);

full_host_name=sprintf('%s.dhe.duke.edu',target_machine);% This is a pretty stupid way to fix the unneccessary 'fix' James introduced
%full_host_name=databuffer.scanner_constants.scanner_host_name; % Just kidding. We can thank James for this red herring.

% Recon file should contain
%scale_file
%fid_tag_file
%dim_x,dim_y,dim_z
%scanner
%runno
%study
%series
% processed options
%options:
%target_machine
%fermi_filter (and w1/w2)
%chunk_size
%CS_recon_parameters: TVWeight,xfmWeight,Itnlim,wavelet_dims,wavelet_type
%% Reservation support
active_reservation=get_reservation(options.CS_reservation);
%% queue settings
gatekeeper_queue = getenv('CS_GATEKEEPER_QUEUE');
if isempty(gatekeeper_queue)
    gatekeeper_queue = 'slow_master';%'high_priority';
end
cs_full_volume_queue = getenv('CS_FULL_VOLUME_QUEUE');
if isempty(cs_full_volume_queue)
    cs_full_volume_queue = 'slow_master';%'high_priority';
end
cs_recon_queue = getenv('CS_RECON_QUEUE');
if isempty(cs_recon_queue)
    cs_recon_queue = 'matlab';
end
%% Executables support
matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
gatekeeper_exec_path = getenv('CS_GATEKEEPER_EXEC'); % Error check for isempty?

volume_manager_exec_path = getenv('CS_VOLUME_MANAGER_EXEC'); % Error check for isempty?
if isempty(volume_manager_exec_path) % Temporary fix.
    volume_manager_exec_path =  which(mfilename);
    %volume_manager_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/20171003_0904/run_volume_manager_exec.sh';
    setenv('CS_VOLUME_MANAGER_EXEC',volume_manager_exec_path);
end
% set an env var to get latest dev code, or will defacto run stable.
CS_CODE_DEV=getenv('CS_CODE_DEV');
if isempty(CS_CODE_DEV)
    CS_CODE_DEV='stable';
end
volume_setup_exec_path = getenv('CS_VOLUME_SETUP_EXEC'); % Error check for isempty?
if isempty(volume_setup_exec_path)
    %volume_setup_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/setup_volume_work_for_CSrecon_executable/20171026_1816/run_setup_volume_work_for_CSrecon_exec.sh';
    %volume_setup_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/setup_volume_work_for_CSrecon_executable/20171030_1349/run_setup_volume_work_for_CSrecon_exec.sh';
    %volume_setup_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/setup_volume_work_for_CSrecon_executable/stable/run_setup_volume_work_for_CSrecon_exec.sh';
    volume_setup_exec_path = ['/cm/shared/workstation_code_dev/matlab_execs/setup_volume_work_for_CSrecon_executable/' CS_CODE_DEV '/run_setup_volume_work_for_CSrecon_exec.sh' ];
    setenv('CS_VOLUME_SETUP_EXEC',volume_setup_exec_path);
end
slicewise_recon_exec_path = getenv('CS_SLICEWISE_RECON_EXEC'); % Error check for isempty?

if isempty(slicewise_recon_exec_path)
    %slicewise_recon_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/slicewise_CSrecon_executable/20171002_1551/run_slicewise_CSrecon_exec.sh';
    %slicewise_recon_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/slicewise_CSrecon_executable/stable/run_slicewise_CSrecon_exec.sh';
    slicewise_recon_exec_path = ['/cm/shared/workstation_code_dev/matlab_execs/slicewise_CSrecon_executable/' CS_CODE_DEV '/run_slicewise_CSrecon_exec.sh'] ;
    
    setenv('CS_SLICEWISE_RECON_EXEC',slicewise_recon_exec_path);
end
volume_cleanup_exec_path = getenv('CS_VOLUME_CLEANUP_EXEC'); % Error check for isempty?
if isempty(volume_cleanup_exec_path)
    %volume_cleanup_exec_path = '/cm/shared/workstation_code_dev/matlab_execs/volume_cleanup_for_CSrecon_executable/20171005_1536/run_volume_cleanup_for_CSrecon_exec.sh';
    %volume_cleanup_exec_path = ['/cm/shared/workstation_code_dev/matlab_execs/volume_cleanup_for_CSrecon_executable/stable/run_volume_cleanup_for_CSrecon_exec.sh'];
    volume_cleanup_exec_path = ['/cm/shared/workstation_code_dev/matlab_execs/volume_cleanup_for_CSrecon_executable/' CS_CODE_DEV '/run_volume_cleanup_for_CSrecon_exec.sh'];
    setenv('CS_VOLUME_CLEANUP_EXEC',volume_cleanup_exec_path);
end
%{
%Moved to deploy_procpar_handlers function
procpar_gatekeeper_exec_path = getenv('CS_PROCPAR_GATEKEEPER_EXEC'); % Error check for isempty?
if isempty(procpar_gatekeeper_exec_path)
    %procpar_gatekeeper_exec_path ='/cm/shared/workstation_code_dev/matlab_execs/local_file_gatekeeper_executable/20171004_1110//run_local_file_gatekeeper_exec.sh';
    %procpar_gatekeeper_exec_path ='/cm/shared/workstation_code_dev/matlab_execs/local_file_gatekeeper_executable/stable/run_local_file_gatekeeper_exec.sh';
    procpar_gatekeeper_exec_path =['/cm/shared/workstation_code_dev/matlab_execs/local_file_gatekeeper_executable/' CS_CODE_DEV '/run_local_file_gatekeeper_exec.sh'];
    setenv('CS_PROCPAR_GATEKEEPER_EXEC',procpar_gatekeeper_exec_path);
end
procpar_cleanup_exec_path = getenv('CS_PROCPAR_CLEANUP_EXEC');
if isempty(procpar_cleanup_exec_path)
    %procpar_cleanup_exec_path='/cm/shared/workstation_code_dev/matlab_execs/process_headfile_CS_executable/20171010_1529/run_process_headfile_CS.sh';
    %procpar_cleanup_exec_path='/cm/shared/workstation_code_dev/matlab_execs/process_headfile_CS_executable/stable/run_process_headfile_CS.sh';
    procpar_cleanup_exec_path=['/cm/shared/workstation_code_dev/matlab_execs/process_headfile_CS_executable/' CS_CODE_DEV '/run_process_headfile_CS.sh'];
    setenv('CS_PROCPAR_CLEANUP_EXEC',procpar_cleanup_exec_path);
end
%}
%%
if ischar(volume_number)
    volume_number=str2double(volume_number);
end
if strcmp('/',workdir(end))
    workdir=[workdir '/'];
end

%% Preflight checks
% Determining where we need to start doing work, setting up folders as
% needed.
% 0 : Source fid not ready, run gatekeeper.
% 1 : Extract fid.
% 2 : Run volume setup.
% 3 : Schedule slice jobs.
% 4 : Run volume cleanup.
% 5 : Send volume to workstation and write recon_completed flag.
% 6 : All work done; do nothing.

% Looks like we have a logic glitch where we dont re-run manager unless
% volume cleanup still has yet to run. SO, lets change that(its at the
% end!).


[starting_point, log_msg] = check_status_of_CSrecon(workdir,volume_runno,scanner,runno,study,agilent_series,bbytes);
log_mode = 1;
yet_another_logger(log_msg,log_mode,log_file);
% Initialize a log file if it doesn't exist yet.
volume_log_file = [workdir '/' volume_runno '.recon_log'];
if ~exist(volume_log_file,'file')
    system(['touch ' volume_log_file]);
end
work_subfolder = [workdir '/work/'];
%variables_file = [work_subfolder     volume_runno '_setup_variables.mat'];
variables_file = [workdir        '/' volume_runno '_setup_variables.mat'];
images_dir =     [workdir        '/' volume_runno 'images/'];
headfile =       [images_dir         volume_runno '.headfile'];

temp_file =      [work_subfolder '/' volume_runno '.tmp'];
volume_fid =     [work_subfolder '/' volume_runno '.fid'];

hf_fail_flag=         sprintf('%s/.%s_send_headfile_to_%s_FAILED',        images_dir,volume_runno,target_machine);
hf_success_flag=      sprintf('%s/.%s_send_headfile_to_%s_SUCCESSFUL',    images_dir,volume_runno,target_machine);
fail_flag=            sprintf('%s/.%s_send_images_to_%s_FAILED',          images_dir,volume_runno,target_machine);
success_flag=         sprintf('%s/.%s_send_images_to_%s_SUCCESSFUL',      images_dir,volume_runno,target_machine);
at_fail_flag=         sprintf('%s/.%s_send_archive_tag_to_%s_FAILED',     images_dir,volume_runno,target_machine);
at_success_flag=      sprintf('%s/.%s_send_archive_tag_to_%s_SUCCESSFUL', images_dir,volume_runno,target_machine);
original_archive_tag= sprintf('%s/READY_%s',images_dir,volume_runno);
local_archive_tag_prefix = [volume_runno '_' target_machine];
local_archive_tag =   sprintf('%s/READY_%s',images_dir,local_archive_tag_prefix);


%TEMPCODE
%{
% Commenting out this temp code 2018-09-28 in the omega removal transition
variables_file2 = [work_subfolder       '/' volume_runno '_setup_variables.mat'];
if (exist(variables_file2,'file'))
    if ~exist(variables_file,'file')
        [t_workdir, t_file_name, t_ext]=fileparts(variables_file);
        old_vv_file = [t_workdir '/work/' t_file_name t_ext];
        mv_cmd = ['mv ' old_vv_file ' ' variables_file];
        if exist(old_vv_file,'file')
            system(mv_cmd);
        end
    end
    mf = matfile(variables_file2,'Writable',true);
    mf.volume_runno = volume_runno;
    write_archive_tag_success_cmd = sprintf('if [[ -f %s ]]; then\n\trm %s;\nfi;\nif [[ ${archive_tag_success} -eq 1 ]];\nthen\n\techo "Archive tag transfer successful!"\n\ttouch %s;\nelse\n\ttouch %s; \nfi',at_fail_flag,at_fail_flag,at_success_flag,at_fail_flag);
    handle_archive_tag_cmd = sprintf('if [[ ! -f %s ]]; then\n\tarchive_tag_success=0;\n\tif [[ -f %s ]] && [[ -f %s ]]; then\n\t\tscp -p %s omega@%s:/Volumes/%sspace/Archive_Tags/READY_%s && archive_tag_success=1;\n\t\t%s;\n\tfi;\nfi',at_success_flag, success_flag, hf_success_flag,local_archive_tag,full_host_name,target_machine,volume_runno,write_archive_tag_success_cmd);
    mf.handle_archive_tag_cmd=handle_archive_tag_cmd;
end
%}

% Write archive tag file before any work done. 
% This is rather poor form as the purpose of the archive tag file is to
% mark data which is ready.
% TODO: move this into the cleanup code.
if ~exist(local_archive_tag,'file')
    if ~exist(original_archive_tag,'file')
        write_archive_tag_nodev(volume_runno,['/' target_machine 'space'], ...
            original_dims(3),databuffer.headfile.U_code, ...
            '.raw',databuffer.headfile.U_civmid,true,images_dir);
    end
    system(sprintf('mv %s %s',original_archive_tag,local_archive_tag));
end

if (starting_point == 0) ||  (  (nechoes > 1) && (starting_point == 1)  )
    % FID not ready yet, schedule gatekeeper for us.
    gk_slurm_options=struct;
    gk_slurm_options.v=''; % verbose
    gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
    gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount.
    gk_slurm_options.p=gatekeeper_queue;
    %gk_slurm_options.job_name = [volume_runno '_gatekeeper'];
    gk_slurm_options.job_name = [runno '_gatekeeper']; %Trying out singleton behavior
    %gk_slurm_options.reservation = active_reservation;
    % using a blank reservation to force no reservation for this job.
    gk_slurm_options.reservation = '';
    study_gatekeeper_batch = [workdir '/sbatch/' volume_runno '_gatekeeper.bash'];
    [input_fid,~] =find_input_fidCS(scanner,runno,study,agilent_series);% hint: ~ ==> local_or_streaming_or_static
    gatekeeper_args= sprintf('%s %s %s %s %i %i', ...
        volume_fid, input_fid, scanner, log_file, volume_number, bbytes);
    gatekeeper_cmd = sprintf('%s %s %s ', gatekeeper_exec_path, matlab_path,...
        gatekeeper_args);
    if ~options.live_run
        batch_file = create_slurm_batch_files(study_gatekeeper_batch,gatekeeper_cmd,gk_slurm_options);
        running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
    else
        running_jobs='';
        eval(sprintf('gatekeeper_exec %s',gatekeeper_args));
    end
    vm_slurm_options=struct;
    vm_slurm_options.v=''; % verbose
    vm_slurm_options.s=''; % shared; volume manager needs to share resources.
    vm_slurm_options.mem=512; % memory requested; vm only needs a miniscule amount.
    vm_slurm_options.p=cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
    vm_slurm_options.job_name = [volume_runno '_volume_manager'];
    %vm_slurm_options.reservation = active_reservation;
    % using a blank reservation to force no reservation for this job.
    vm_slurm_options.reservation = '';
    volume_manager_batch = [workdir 'sbatch/' volume_runno '_volume_manager.bash'];
    vm_args=sprintf('%s %s %i %s',recon_file,volume_runno, volume_number,base_workdir);
    vm_cmd = sprintf('%s %s %s', volume_manager_exec_path,matlab_path,vm_args);
    if ~options.live_run
        batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
        or_dependency = '';
        if ~isempty(running_jobs)
            or_dependency='afterok-or';
        end
        c_running_jobs = dispatch_slurm_jobs(batch_file,'',running_jobs,or_dependency);
    else
        eval(sprintf('volume_manager_exec %s',vm_args));
    end
    log_mode = 1;
    log_msg =sprintf('Fid data for volume %s not available yet; initializing gatekeeper (SLURM jobid(s): %s).\n',volume_runno,running_jobs);
    yet_another_logger(log_msg,log_mode,log_file);
    if ~options.live_run
        quit force
    else
        return;
    end
else
    stage_1_running_jobs='';
    stage_2_running_jobs='';
    stage_3_running_jobs='';
    stage_4_running_jobs='';
    stage_5_running_jobs='';
    stage_5e_running_jobs='';
    
    if (~options.process_headfiles_only)
        % James pulled this input fid check up out of starting point 1 to
        % make it easier to handle procpar processing decisions later.
        [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
        %% STAGE1 Scheduling
        if (starting_point <= 1)
            volume_fid = [work_subfolder '/' volume_runno '.fid'];
            scanner_user='';
            if (local_or_streaming_or_static == 1)
                fid_consistency = write_or_compare_fid_tag(input_fid,fid_tag_file,volume_number);
            else
                scanner_user='omega';
                fid_consistency = write_or_compare_fid_tag(input_fid,fid_tag_file,volume_number,scanner,scanner_user);
            end
            if fid_consistency
                %{
                % James commented this out because it was killing streaming CS,
                % when streaming data.
                % This code needs to be put someplace correct! 
                if ~exist(procpar_file,'file')
                    datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
                    mode =2; % Only pull procpar file
                    puller_glusterspaceCS_2(runno,datapath,scanner,base_workdir,mode);
                end
                %}
                % Getting subvolume should be the job of volume setup. 
                % TODO: Move get vol code into setup!
                if (local_or_streaming_or_static == 1)
                    get_subvolume_from_fid(input_fid,volume_fid,volume_number,bbytes);
                else
                    get_subvolume_from_fid(input_fid,volume_fid,volume_number,bbytes,scanner,scanner_user);
                end
            else
                log_mode = 1;
                error_flag = 1;
                log_msg = sprintf('Fid consistency failure at volume %s! source fid for (%s) is not the same source fid as the first volume''s fid.\n',volume_runno,input_fid);
                log_msg = sprintf('%sCan manual check with "write_or_compare_fid_tag(''%s'',''%s'',%i,''%s'',''%s'')"\n',log_msg,input_fid,fid_tag_file,volume_number,scanner,scanner_user);
                log_msg = sprintf('%sCRITICAL ERROR local_or_streaming_or_static=%i\n',log_msg,local_or_streaming_or_static);
                
                yet_another_logger(log_msg,log_mode,log_file,error_flag);
                status=variable_to_force_an_error;
                quit force
            end
        end
        %% STAGE2 Scheduling
        if (starting_point <= 2)
            % Schedule setup
            %% Make variable file
            if ~exist(variables_file,'file')
                cp_cmd = sprintf('cp %s %s',recon_file, variables_file);
                system(cp_cmd);
            end
            mf = matfile(variables_file,'Writable',true);
            mf.work_subfolder = work_subfolder;
            mf.recon_file = recon_file;
            mf.procpar_file = procpar_file;
            mf.scale_file = scale_file;
            mf.volume_runno = volume_runno;
            mf.volume_log_file = volume_log_file;
            mf.volume_fid = [work_subfolder '/' volume_runno '.fid'];
            mf.workdir = workdir;
            mf.temp_file = temp_file;
            mf.images_dir =images_dir;
            mf.headfile = headfile;
            if exist('target_machine','var')
                mf.target_machine = target_machine;
            end
            if exist('wavelet_dims','var')
                mf.wavelet_dims = wavelet_dims;
            end
            if exist('wavelet_type','var')
                mf.wavelet_type = wavelet_type;
            end
            if exist('TVWeight','var')
                mf.TVWeight = TVWeight;
            end
            if exist('xfmWeight','var')
                mf.xfmWeight=xfmWeight;
            end
            if exist('Itnlim','var')
                mf.Itnlim = Itnlim;
            end
            %% Schedule setup via slurm and record jobid for dependency scheduling.
            vsu_slurm_options=struct;
            vsu_slurm_options.v=''; % verbose
            vsu_slurm_options.s=''; % shared; volume setup should to share resources.
            vsu_slurm_options.mem=50000; % memory requested; vsu needs a significant amount; could do this smarter, though.
            vsu_slurm_options.p=cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
            vsu_slurm_options.job_name = [volume_runno '_volume_setup_for_CS_recon'];
            %vsu_slurm_options.reservation = active_reservation;
            % using a blank reservation to force no reservation for this job.
            vsu_slurm_options.reservation = ''; 
            volume_setup_batch = [workdir 'sbatch/' volume_runno '_volume_setup_for_CS_recon.bash'];
            vsu_args=sprintf('%s %i',variables_file, volume_number);
            vsu_cmd = sprintf('%s %s %s', volume_setup_exec_path,matlab_path, vsu_args);
            if ~options.live_run
                batch_file = create_slurm_batch_files(volume_setup_batch,vsu_cmd,vsu_slurm_options);
                stage_2_running_jobs = dispatch_slurm_jobs(batch_file,'');
            else
                eval(sprintf('setup_volume_work_for_CSrecon_exec %s',vsu_args));
            end
        end
        if options.CS_preview_data
            return;
        end
        %% STAGE3 Scheduling
        if (starting_point <= 3)
            mf = matfile(variables_file,'Writable',true);
            rf = matfile(recon_file);
            opts2=rf.options;
            Itnlim = opts2.Itnlim;
            opts3=mf.options;
            opts3.Itnlim=Itnlim;
            mf.options=opts3;
            volume_variable_file = [work_subfolder volume_runno '_workspace.mat'];
            if exist(volume_variable_file,'file')
                mf2=matfile(volume_variable_file,'Writable',true);
                t_param=mf2.param;
                t_param.Itnlim=Itnlim;
                mf2.param=t_param;
                if isfield(options,'verbosity')
                    t_aux_param=mf2.aux_param;
                    t_aux_param.verbosity=options.verbosity;
                    mf2.aux_param=t_aux_param;
                end
            end
            % Schedule slice jobs
            if ~exist('recon_options_file','var')
                recon_options_file='';
            end
            if chunk_size > 1
                plural = 's';
            else
                plural = '';
            end
            single_threaded_recon =1;
            swr_slurm_options=struct;
            swr_slurm_options.v=''; % verbose
            if single_threaded_recon
                swr_slurm_options.c=1; % was previously 2...also need to investigate binding
                swr_slurm_options.hint='nomultithread';
            else
                swr_slurm_options.s='';
                swr_slurm_options.hint='multithread';
            end
            % We use mem limit to control the number of jobs per node. 
            % Want to allow 32-40 jobs per node, but use --ntasks-per-core=1 
            % to make sure that every core has exactly one job on them.
            % That is why this mem number gets to be constant, we shouldnt
            % run into trouble until CS_slices are very (VERY) large. 
            swr_slurm_options.mem='5900'; 
            swr_slurm_options.p=cs_recon_queue;
            swr_slurm_options.job_name=[volume_runno '_CS_recon_' num2str(chunk_size) '_slice' plural '_per_job'];
            swr_slurm_options.reservation = active_reservation;
            if exist(temp_file,'file')
                %Find slices that need to be reconned. 
                % the temp file only exists if setup has run. 
                [~,~,tmp_header] = read_header_of_CStmp_file(temp_file);
                if length(tmp_header) > 2
                    slices_to_process = find(~tmp_header);
                    if isfield(options,'keep_work')
                        if options.keep_work
                            %% Currently iteration limit is not a part of the recon.mat variable group...will need to add it.
                            slices_to_process = find(tmp_header<Itnlim);
                        end
                    end
                    if isempty(slices_to_process)
                        slices_to_process = 0;
                    end
                else
                    slices_to_process =1:1:original_dims(1);
                end
            else
                slices_to_process = 1:1:original_dims(1);
            end
            
            if slices_to_process
                zero_width = ceil(log10((original_dims(1)+1)));
                num_chunks = ceil(length(slices_to_process)/chunk_size);
                log_msg =sprintf('Volume %s: Number of chunks (independent jobs): %i.\n',volume_runno,num_chunks);
                yet_another_logger(log_msg,log_mode,log_file);
                new_size = num_chunks*chunk_size;
                temp_size=length(slices_to_process);
                log_msg =sprintf('Volume %s: Number of slices to be reconstructed: %i.\n',volume_runno,temp_size);
                yet_another_logger(log_msg,log_mode,log_file);
                
                while new_size > temp_size
                    slices_to_process = [slices_to_process NaN];
                    temp_size = size(slices_to_process);
                end
                slices_to_process = reshape(slices_to_process,[chunk_size num_chunks]);
                for slice = slices_to_process
                    slice_string = sprintf(['' '%0' num2str(zero_width) '.' num2str(zero_width) 's'] ,num2str(slice(1)));
                    slice(isnan(slice))=[];
                    if length(slice)>3
                        no_con_test = sum(diff(diff(slice)));
                    else
                        no_con_test = 1;
                    end
                    for ss = 2:length(slice)
                        if (no_con_test)
                            slice_string = [slice_string '_' sprintf(['' '%0' num2str(zero_width) '.' num2str(zero_width) 's'] ,num2str(slice(ss)))];
                        elseif (ss==length(slice))
                            slice_string = [slice_string '_to_' sprintf(['' '%0' num2str(zero_width) '.' num2str(zero_width) 's'] ,num2str(slice(ss)))];
                        end
                    end
                    slicewise_recon_batch = [workdir 'sbatch/' volume_runno '_slice' slice_string '_CS_recon.bash'];
                    swr_args= sprintf('%s %s %s', volume_variable_file, slice_string,recon_options_file);
                    swr_cmd = sprintf('%s %s %s', slicewise_recon_exec_path,matlab_path,swr_args);
                    if  stage_2_running_jobs
                        dep_string = stage_2_running_jobs;
                        dep_type = 'afterok-or';
                    else
                        dep_string = '';
                        dep_type = '';
                    end
                    c_running_jobs ='';
                    if ~options.live_run
                        batch_file = create_slurm_batch_files(slicewise_recon_batch,swr_cmd,swr_slurm_options);
                        [c_running_jobs, msg1,msg2]= dispatch_slurm_jobs(batch_file,'',dep_string,dep_type);
                        if msg1
                            disp(msg1)
                        end
                        if msg2
                            disp(msg2)
                        end
                    else
                        eval(sprintf('slicewise_CSrecon_exec %s',swr_args));
                        starting_point=4;
                    end
                    if c_running_jobs
                        %if stage_3_running_jobs
                        stage_3_running_jobs = [stage_3_running_jobs ':' c_running_jobs];
                        %else
                        %    stage_3_running_jobs = c_running_jobs;
                        %end
                    end
                end
                if stage_3_running_jobs
                    if strcmp(':',stage_3_running_jobs(1))
                        stage_3_running_jobs(1)=[];
                    end
                end
            end
        end
        %% craft archive tag commands for later. 
        write_archive_tag_success_cmd = ...
            sprintf(['if [[ -f %s ]]; then\n'...
            '\t  rm %s;\n'...
            'fi;\n'...
            'if [[ ${archive_tag_success} -eq 1 ]];\n'...
            'then\n'...
            '\t  echo "Archive tag transfer successful!"\n'...
            '\t  touch %s;\n'...
            'else\n'...
            '\t  touch %s; \n'...
            'fi'],at_fail_flag,at_fail_flag,at_success_flag,at_fail_flag);
        handle_archive_tag_cmd = ...
            sprintf(['if [[ ! -f %s ]]; then\n'...
            '\t  archive_tag_success=0;\n'...
            '\t  if [[ -f %s ]] && [[ -f %s ]]; then\n'...
            '\t  \t  scp -p %s %s@%s:/Volumes/%sspace/Archive_Tags/READY_%s && archive_tag_success=1;\n'...
            '\t  \t  %s;\n'...
            '\t  fi;\n'...
            'fi'],at_success_flag, success_flag, hf_success_flag, ...
            local_archive_tag,getenv('USER'),full_host_name,target_machine,volume_runno,write_archive_tag_success_cmd);
        mf2 = matfile(variables_file,'Writable',true);
        mf2.handle_archive_tag_cmd=handle_archive_tag_cmd;
        %% STAGE4 Scheduling
        if (starting_point <= 4)
            %% Schedule via slurm and record jobid for dependency scheduling.
            if ~exist('plural','var')
                if chunk_size > 1
                    plural = 's';
                else
                    plural = '';
                end
            end
            vcu_slurm_options=struct;
            vcu_slurm_options.v=''; % verbose
            vcu_slurm_options.s=''; % shared; volume setup should to share resources.
            vcu_slurm_options.mem=66000; % memory requested; vcu needs a significant amount; could do this smarter, though.
            vcu_slurm_options.p=cs_full_volume_queue; % Really want this to be high_priority, and will usually be that.
            vcu_slurm_options.job_name =[volume_runno '_CS_recon_' num2str(chunk_size) '_slice' plural '_per_job'];
            %vcu_slurm_options.reservation = active_reservation;
            % using a blank reservation to force no reservation for this job.
            vcu_slurm_options.reservation = ''; 
            volume_cleanup_batch = [workdir 'sbatch/' volume_runno '_volume_cleanup_for_CS_recon.bash'];
            vcu_args=sprintf('%s',variables_file);
            vcu_cmd = sprintf('%s %s %s', volume_cleanup_exec_path,matlab_path,vcu_args);
            if ~options.live_run
                batch_file = create_slurm_batch_files(volume_cleanup_batch,vcu_cmd,vcu_slurm_options);
                maybe_im_a_singleton='';
                if (stage_3_running_jobs)
                    maybe_im_a_singleton='singleton';
                end
                stage_4_running_jobs = dispatch_slurm_jobs(batch_file,'',maybe_im_a_singleton);
            else
                eval(sprintf('volume_cleanup_for_CSrecon_exec %s',vcu_args));
                starting_point=5;
            end
        end
        %% STAGE5 Scheduling
        if (starting_point <= 5)
            if ~options.keep_work
                % Send to workstation and write completion flag.
                %rm_previous_flag = sprintf('if [[ -f %s ]]; then rm %s; fi',fail_flag,fail_flag);
                t_images_dir = images_dir;
                mkdir_cmd = sprintf('ssh %s@%s ''mkdir -p -m 777 /Volumes/%sspace/%s/%simages/''',...
                    getenv('USER'),full_host_name,target_machine,volume_runno,volume_runno);
                scp_cmd = sprintf(['echo "Attempting to transfer data to %s.";' ...
                    'scp -r %s %s@%s:/Volumes/%sspace/%s/ && success=1'], ...
                    target_machine,t_images_dir,getenv('USER'),full_host_name,target_machine,volume_runno);
                write_success_cmd = sprintf('if [[ $success -eq 1 ]];\nthen\n\techo "Transfer successful!"\n\ttouch %s;\nelse\n\ttouch %s; \nfi',success_flag,fail_flag);
                %{
                local_size_cmd = sprintf('gimmespaceK=`du -cks %s | tail -n 1 | xargs |cut -d '' '' -f1`',images_dir);
                remote_size_cmd = sprintf('freespaceK=`ssh omega@%s.dhe.duke.edu ''df -k /Volumes/%sspace ''| tail -1 | cut -d '' '' -f5`',target_machine,target_machine);
                eval_cmd = sprintf(['success=0;\nif [[ $freespaceK -lt $gimmespaceK ]]; then\n\techo "ERROR: not enough space to transfer %s to %s; $gimmespaceK K needed, but only $freespaceK K available."; '...
               'else %s; fi; %s'],  images_dir,target_machine, scp_cmd,write_success_cmd);
                %}
                n_raw_images = original_dims(3);
                shipper_cmds{1}=sprintf('success=0;\nc_raw_images=$(ls %s | grep raw | wc -l | xargs); if [[ "${c_raw_images}"  -lt "%i" ]]; then\n\techo "Not all %i raw images have been written (${c_raw_images} total); no images will be sent to remote machine.";\nelse\nif [[ -f %s ]]; then\n\trm %s;\nfi',images_dir,n_raw_images,n_raw_images,fail_flag,fail_flag);
                shipper_cmds{2}=sprintf('gimmespaceK=`du -cks %s | tail -n 1 | xargs |cut -d '' '' -f1`',images_dir);
                shipper_cmds{3}=sprintf('freespaceK=`ssh %s@%s ''df -k /Volumes/%sspace ''| tail -1 | xargs | cut -d '' '' -f4`', getenv('USER'), full_host_name,  target_machine);
                shipper_cmds{4}=sprintf('if [[ $freespaceK -lt $gimmespaceK ]];');
                shipper_cmds{5}=sprintf('then\n\techo "ERROR: not enough space to transfer %s to %s; $gimmespaceK K needed, but only $freespaceK K available."',images_dir,target_machine);
                shipper_cmds{6}=sprintf('else\n\t%s;\n\t%s;\nfi',mkdir_cmd,scp_cmd);
                shipper_cmds{7}=sprintf('fi\n%s',write_success_cmd);
                shipper_cmds{8}=sprintf('%s',handle_archive_tag_cmd);
                shipper_slurm_options=struct;
                shipper_slurm_options.v=''; % verbose
                shipper_slurm_options.s=''; % shared; volume manager needs to share resources.
                shipper_slurm_options.mem=500; % memory requested; shipper only needs a miniscule amount.
                shipper_slurm_options.p=gatekeeper_queue; % For now, will use gatekeeper queue for volume manager as well
                shipper_slurm_options.job_name = [volume_runno '_ship_to_' target_machine];
                %shipper_slurm_options.reservation = active_reservation;
                % using a blank reservation to force no reservation for this job.
                shipper_slurm_options.reservation = '';
                shipper_batch = [workdir 'sbatch/' volume_runno '_shipper.bash'];
                %batch_file = create_slurm_batch_files(shipper_batch,{rm_previous_flag,local_size_cmd remote_size_cmd eval_cmd},shipper_slurm_options);
                batch_file = create_slurm_batch_files(shipper_batch,shipper_cmds,shipper_slurm_options);
                dep_status='';
                if ~options.live_run
                    if stage_4_running_jobs
                        dep_status='afterok-or';
                    end
                    stage_5_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_4_running_jobs,dep_status);
                else
                    [ship_st,ship_out]=system(sprintf('bash %s',batch_file));
                    if ship_st~=0
                        error(ship_out);
                    end
                end
                %% STAGE5+ Scheduling
                %if (starting_point >= 5)%(starting_point <= 6)
                if (starting_point == 5)%(starting_point <= 6)
                    % This is only scheduled at stage 5 because prior to that it wont
                    % work anyway.
                    stage_5e_running_jobs = deploy_procpar_handlers(variables_file);
                    %% live run startingpoint advance handling
                    if exist('ship_st','var')
                        if ship_st==0
                            starting_point=6;
                        end
                    end
                end
            end
        end
    end
    recon_type = 'CS_v2';
    % Why is volume manager only re-scheduled if we have stage 4(cleanup)
    % jobs? That seems like a clear mistake! We should be rescheduling so
    % long as we're not stage 6.
    %if stage_4_running_jobs
    if starting_point < 6
        vm_slurm_options=struct;
        vm_slurm_options.v=''; % verbose
        vm_slurm_options.s=''; % shared; volume manager needs to share resources.
        vm_slurm_options.mem=2048; % memory requested; vm only needs a miniscule amount.
            %--In theory only! For yz-array sizes > 2048^2, loading the
            % data of phmask, CSmask, etc can push the memory of 512 MB
        vm_slurm_options.p=cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
        vm_slurm_options.job_name = [volume_runno '_volume_manager'];
        %vm_slurm_options.reservation = active_reservation;
        % using a blank reservation to force no reservation for this job.
        vm_slurm_options.reservation = '';
        volume_manager_batch = [workdir 'sbatch/' volume_runno '_volume_manager.bash'];
        vm_args=sprintf('%s %s %i %s',recon_file,volume_runno, volume_number,base_workdir);
        vm_cmd = sprintf('%s %s %s', volume_manager_exec_path,matlab_path, vm_args);
        if ~options.live_run
            batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
            %{
            if stage_4_running_jobs
                c_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_4_running_jobs,'afternotok');
            elseif stage_5_running_jobs
            end
            %}
            %% re-configured to run as singleton so long as we're not stage 5.
            % and we scheduled procpar jobs.
            if starting_point==5 && stage_5e_running_jobs
                c_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_5e_running_jobs,'afternotok');
            else
                c_running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
            end
            
            log_mode = 1;
            log_msg =sprintf('If original cleanup jobs for volume %s fail, volume_manager will be re-initialized (SLURM jobid(s): %s).\n',volume_runno,c_running_jobs);
            yet_another_logger(log_msg,log_mode,log_file);
        else
            eval(sprintf('volume_manager_exec %s',vm_args));
            pause(1);
        end
    end
end

