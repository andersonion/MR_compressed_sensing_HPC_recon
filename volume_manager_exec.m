function starting_point = volume_manager_exec(recon_file,volume_runno, volume_number,base_workdir)
% Manages the  compressed sensing reconstruction of an independent 3D volume
% % Functions similarly to old code CS_recon_cluster_bj_multithread_v2[a]
%
%
% Written by BJ Anderson, CIVM
% 21 September 2017

if ~isdeployed
    recon_file='/nas4/cof/S67960.work/S67960recon.mat';
    volume_runno='S67960_m023';
    volume_number='24';
    base_workdir='/nas4/cof/S67960.work/';
end
%%% ORIGINAL COMMENT
% This may seem stupid, but I need to let Matlab know that I'm going need
% series to be a variable, and not the builtin function 'series'
%%%%
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
active_reservation=getenv('CS_reservation'); % This should work fine, even if CS_reservation is not set.
% Ensure that reservation exists
if (active_reservation)
    [~, res_check] = system(['scontrol show reservation ' active_reservation]);
    res_check = strtrim(res_check);
    failure_string = ['Reservation ' active_reservation ' not found'];
    if strcmp(res_check,failure_string)
        active_reservation = '';
    end
end
%% Executables support
matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
gatekeeper_exec = getenv('CS_GATEKEEPER_EXEC'); % Error check for isempty?
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
if ischar(volume_number)
    volume_number=str2double(volume_number);
end
if strcmp('/',workdir(end))
    workdir=[workdir '/'];
end
%{
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
starting_point = 6;
% Check for recon flag
volume_flag = [workdir '/.' volume_runno '.recon_completed'];
if ~exist(volume_flag,'file')CS_CODE_DEV
    starting_point = 5;
    % Check for output images
    images_dir = [workdir '/' volume_runno 'images/'];
    if ~exist(images_dir,'dir')
        system(['mkdir -m 777 ' images_dir]);
    end
    finished_slices = dir( [images_dir '/*.raw' ]);
    finished_slices_count = length(finished_slices(not([finished_slices.isdir])));
    if (finished_slices_count == 0) % We assume that all the raw files were written at once, and correctly so.
        starting_point = 4;
        % Check .tmp file to see if all slices have reconned.
        work_subfolder = [workdir '/work/'];
        if ~exist(work_subfolder,'dir')
            system(['mkdir -m 777 ' work_subfolder]);
        end
        temp_file = [work_subfolder '/' volume_runno '.tmp'];
        if exist(temp_file,'file')
            [slices_remaining,~,~] = read_header_of_CStmp_file(temp_file);  % Need to remember that we are going to add the headersize as the first bytes
        else
            slices_remaining = 1; % Will not bother to determine the exact number here.
        end
        if (slices_remaining)
            starting_point = 3;
            % Check for a complete workspace file
            workspace_file = [work_subfolder '/' volume_runno '_workspace.mat'];
            try
                %dummy = load(workspace_file,'aux_param.maskSize'); % Need to try to load an arbitrary variable from the work file
                dummy_mf = matfile(workspace_file,'Writable',false);
                tmp_param = dummy_mf.param;
                workspace_is_ready = 1;
            catch
                workspace_is_ready = 0;
            end
            if ~workspace_is_ready
                starting_point = 2;
                % Check to see if the volume fid is ready.
                volume_fid = [work_subfolder '/' volume_runno '.fid'];
                if ~exist(volume_fid,'file')
                    starting_point = 1;
                    % Need to remember to  handle differently for single
                    % blocks scans...I think (I haven't put in the split code for this yet!).
                    [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,series);
                    if (local_or_streaming_or_static == 2)
                        remote_user='omega';
                        ready=check_subvolume_ready_in_fid_quiet(input_fid,volume_number,bbytes,scanner,remote_user);
                        if ~ready
                            starting_point = 0;
                        end
                    end
                end
            end
        end
    end
end
%}

[starting_point, log_msg] = check_status_of_CSrecon(workdir,volume_runno,scanner,runno,study,agilent_series,bbytes);
log_mode = 1;
%%l%og_msg =sprintf('Starting point for volume %s: Stage %i.\n',volume_runno,starting_point);
yet_another_logger(log_msg,log_mode,log_file);
% Initialize a log file if it doesn't exist yet.
volume_log_file = [workdir '/' volume_runno '.recon_log'];
if ~exist(volume_log_file,'file')
    system(['touch ' volume_log_file]);
end
work_subfolder = [workdir '/work/'];
variables_file = [work_subfolder volume_runno '_setup_variables.mat'];
temp_file = [work_subfolder '/' volume_runno '.tmp'];
volume_fid = [work_subfolder '/' volume_runno '.fid'];
images_dir= [workdir '/' volume_runno 'images/'];
headfile = [images_dir volume_runno '.headfile'];
hf_fail_flag=sprintf('%s/.%s_send_headfile_to_%s_FAILED', images_dir,volume_runno,target_machine);
hf_success_flag=sprintf('%s/.%s_send_headfile_to_%s_SUCCESSFUL', images_dir,volume_runno,target_machine);
fail_flag=sprintf('%s/.%s_send_images_to_%s_FAILED', images_dir,volume_runno,target_machine);
success_flag=sprintf('%s/.%s_send_images_to_%s_SUCCESSFUL', images_dir,volume_runno,target_machine);
at_fail_flag=sprintf('%s/.%s_send_archive_tag_to_%s_FAILED', images_dir,volume_runno,target_machine);
at_success_flag=sprintf('%s/.%s_send_archive_tag_to_%s_SUCCESSFUL', images_dir,volume_runno,target_machine);
original_archive_tag=sprintf('%s/READY_%s',images_dir,volume_runno);
local_archive_tag_prefix = [volume_runno '_' target_machine];
local_archive_tag = sprintf('%s/READY_%s',images_dir,local_archive_tag_prefix);

% Make faux headfile with minimal details (will overwrite later).
%if ~exist(headfile,'file')
bh=struct;
bh.dim_X=original_dims(1);
bh.dim_Y=original_dims(2);
bh.dim_Z=original_dims(3);
% TEMPORARY CODE!!
%bh.fovx=original_dims(1);
%bh.fovy=original_dims(2);
%bh.fovz=original_dims(3);
% End temp code
bh.A_dti_vols=n_volumes;
bh.A_channels = 1;
bh.A_echoes = nechoes;
bh.U_runno = volume_runno;
gui_info = read_headfile(fullfile(databuffer.engine_constants.engine_recongui_paramfile_directory,[runno '.param']));
faux_struct1 = combine_struct(bh,gui_info,'U_');
databuffer.headfile = combine_struct(databuffer.headfile,faux_struct1);
if ~exist(headfile,'file')
    write_headfile(headfile,databuffer.headfile);
    
    ship_cmd = sprintf('scp %s omega@%s:/Volumes/%sspace/%s/',headfile,full_host_name,target_machine,volume_runno);
    system(ship_cmd);
end
if ~exist(local_archive_tag,'file')
    if ~exist(original_archive_tag,'file')
        write_archive_tag_nodev(volume_runno,['/' target_machine 'space'],original_dims(3),databuffer.headfile.U_code, ...
            '.raw',databuffer.headfile.U_civmid,true,images_dir)
    end
    
    system(sprintf('mv %s %s',original_archive_tag,local_archive_tag));
end
if (~starting_point) || ((nechoes > 1) && (starting_point == 1))
    gk_slurm_options=struct;
    gk_slurm_options.v=''; % verbose
    gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
    gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount.
    gk_slurm_options.p=gatekeeper_queue;
    %gk_slurm_options.job_name = [volume_runno '_gatekeeper'];
    gk_slurm_options.job_name = [runno '_gatekeeper']; %Trying out singleton behavior
    %gk_slurm_options.reservation = active_reservation;
    study_gatekeeper_batch = [workdir '/sbatch/' volume_runno '_gatekeeper.bash'];
    [input_fid,~] =find_input_fidCS(scanner,runno,study,agilent_series);% hint: ~ ==> local_or_streaming_or_static
    gatekeeper_cmd = sprintf('%s %s %s %s %s %s %i %i', gatekeeper_exec, matlab_path,volume_fid,input_fid,scanner,log_file,volume_number,bbytes);
    batch_file = create_slurm_batch_files(study_gatekeeper_batch,gatekeeper_cmd,gk_slurm_options);
    running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
    vm_slurm_options=struct;
    vm_slurm_options.v=''; % verbose
    vm_slurm_options.s=''; % shared; volume manager needs to share resources.
    vm_slurm_options.mem=512; % memory requested; vm only needs a miniscule amount.
    vm_slurm_options.p=cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
    vm_slurm_options.job_name = [volume_runno '_volume_manager'];
    %vm_slurm_options.reservation = active_reservation;
    volume_manager_batch = [workdir 'sbatch/' volume_runno '_volume_manager.bash'];
    vm_cmd = sprintf('%s %s %s %s %i %s', volume_manager_exec_path,matlab_path, recon_file,volume_runno, volume_number,base_workdir);
    batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
    or_dependency = '';
    if ~isempty(running_jobs)
        or_dependency='afterok-or';
    end
    c_running_jobs = dispatch_slurm_jobs(batch_file,'',running_jobs,or_dependency);
    log_mode = 1;
    log_msg =sprintf('Fid data for volume %s not available yet; initializing gatekeeper (SLURM jobid(s): %s).\n',volume_runno,running_jobs);
    yet_another_logger(log_msg,log_mode,log_file);
    quit force
else
    stage_1_running_jobs='';
    stage_2_running_jobs='';
    stage_3_running_jobs='';
    stage_4_running_jobs='';
    stage_5_running_jobs='';
    
    if (~options.process_headfiles_only)
        if (starting_point <= 1)
            [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
            volume_fid = [work_subfolder '/' volume_runno '.fid'];
            user='';
            if (local_or_streaming_or_static == 1)
                fid_consistency = write_or_compare_fid_tag(input_fid,fid_tag_file,volume_number);
            else
                user='omega';
                fid_consistency = write_or_compare_fid_tag(input_fid,fid_tag_file,volume_number,scanner,user);
            end
            if fid_consistency
                %{
            % James commented this out because it was killing streaming CS,
            % when streaming data.
            if ~exist(procpar_file,'file')
                datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
                mode =2; % Only pull procpar file
                puller_glusterspaceCS_2(runno,datapath,scanner,base_workdir,mode);
            end
                %}
                if (local_or_streaming_or_static == 1)
                    get_subvolume_from_fid(input_fid,volume_fid,volume_number,bbytes);
                else
                    get_subvolume_from_fid(input_fid,volume_fid,volume_number,bbytes,scanner,user);
                end
            else
                log_mode = 1;
                error_flag = 1;
                log_msg = sprintf('Fid consistency failure at volume %s! source fid for (%s) is not the same source fid as the first volume''s fid.\n',volume_runno,input_fid);
                log_msg = sprintf('%sCan manual check with "write_or_compare_fid_tag(''%s'',''%s'',%i,''%s'',''%s'')"\n',log_msg,input_fid,fid_tag_file,volume_number,scanner,user);
                log_msg = sprintf('%sCRITICAL ERROR local_or_streaming_or_static=%i\n',log_msg,local_or_streaming_or_static);
                
                yet_another_logger(log_msg,log_mode,log_file,error_flag);
                status=variable_to_force_an_error;
                quit force
            end
        end
        %stage_2_running_jobs='';
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
            %{
        % Make faux headfile with minimal details (will overwrite later).
        bh=struct;
        bh.dim_X=original_dims(1);
        bh.dim_Y=original_dims(2);
        bh.dim_Z=original_dims(3);
        bh.A_dti_vols=n_volumes;
        bh.A_channels = 1;
        bh.A_echoes = nechoes;
        bh.U_runno = volume_runno;
        gui_info = read_headfile(fullfile(databuffer.engine_constants.engine_recongui_paramfile_directory,[runno '.param']));
        faux_struct1 = combine_struct(bh,gui_info,'U_');
        databuffer.headfile = combine_struct(databuffer.headfile,faux_struct1);
        write_headfile(headfile,databuffer.headfile);
            %}
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
            vsu_slurm_options.reservation = active_reservation;
            volume_setup_batch = [workdir 'sbatch/' volume_runno '_volume_setup_for_CS_recon.bash'];
            vsu_cmd = sprintf('%s %s %s %i', volume_setup_exec_path,matlab_path, variables_file, volume_number);
            batch_file = create_slurm_batch_files(volume_setup_batch,vsu_cmd,vsu_slurm_options);
            stage_2_running_jobs = dispatch_slurm_jobs(batch_file,'');
        end
        %stage_3_running_jobs='';
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
            if ~exist('variables_file','var')
                variables_file = [work_subfolder volume_runno '_setup_variables.mat'];
            end
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
            swr_slurm_options.mem='5900'; % Want to allow 32-40 jobs per node, but use --ntasks-per-core=1 to make sure that every core has exactly one job on them.
            swr_slurm_options.p=cs_recon_queue;
            swr_slurm_options.job_name=[volume_runno '_CS_recon_' num2str(chunk_size) '_slice' plural '_per_job'];
            swr_slurm_options.reservation = active_reservation;
            %Find slices that need to be reconned.
            if exist(temp_file,'file')
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
                    swr_cmd = sprintf('%s %s %s %s %s', slicewise_recon_exec_path,matlab_path, volume_variable_file, slice_string,recon_options_file);
                    if  stage_2_running_jobs
                        dep_string = stage_2_running_jobs;
                        dep_type = 'afterok-or';
                    else
                        dep_string = '';
                        dep_type = '';
                    end
                    batch_file = create_slurm_batch_files(slicewise_recon_batch,swr_cmd,swr_slurm_options);
                    c_running_jobs ='';
                    [c_running_jobs, msg1,msg2]= dispatch_slurm_jobs(batch_file,'',dep_string,dep_type);
                    if c_running_jobs
                        %if stage_3_running_jobs
                        stage_3_running_jobs = [stage_3_running_jobs ':' c_running_jobs];
                        %else
                        %    stage_3_running_jobs = c_running_jobs;
                        %end
                    end
                    if msg1
                        disp(msg1)
                    end
                    if msg2
                        disp(msg2)
                    end
                end
                if stage_3_running_jobs
                    if strcmp(':',stage_3_running_jobs(1))
                        stage_3_running_jobs(1)=[];
                    end
                end
            end
        end
        if (starting_point <= 4)
            % Schedule cleanup
            %         aux_param2.dims=voldims;
            %     aux_param2.voldir=voldir;
            %     aux_param2.tempFile=temp_file;
            %     aux_param2.outpath=outpath;
            %     aux_param2.dir1=dir1;
            %     aux_param2.targetMachine = target_machine;
            %     aux_param2.fermi_filter=fermi_filter;
            %     aux_param2.headfile=headfile;
            %     if exist('w1','var')
            %         aux_param2.fermi_filter_w1=w1;
            %     end
            %     if exist('w2','var')
            %         aux_param2.fermi_filter_w2=w2;
            %     end
            %    cleanup_variable_file = [work_folder dir1 '_cleanup_variable.mat'];
            %     if ~exist(cleanup_variable_file,'file')
            %         %save(cleanup_variable_file,'struct1');
            %         save(cleanup_variable_file,'aux_param2');%,'-append');
            %     end
            %% Schedule setup via slurm and record jobid for dependency scheduling.
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
            volume_cleanup_batch = [workdir 'sbatch/' volume_runno '_volume_cleanup_for_CS_recon.bash'];
            vcu_cmd = sprintf('%s %s %s %i', volume_cleanup_exec_path,matlab_path, variables_file);
            batch_file = create_slurm_batch_files(volume_cleanup_batch,vcu_cmd,vcu_slurm_options);
            maybe_im_a_singleton='';
            if (stage_3_running_jobs)
                maybe_im_a_singleton='singleton';
            end
            stage_4_running_jobs = dispatch_slurm_jobs(batch_file,'',maybe_im_a_singleton);
        end
    end
    
        write_archive_tag_success_cmd = sprintf('if [[ -f %s ]]; then\n\trm %s;\nfi;\nif [[ ${archive_tag_success} -eq 1 ]];\nthen\n\techo "Archive tag transfer successful!"\n\ttouch %s;\nelse\n\ttouch %s; \nfi',at_fail_flag,at_fail_flag,at_success_flag,at_fail_flag);
        handle_archive_tag_cmd = sprintf('if [[ ! -f %s ]]; then\n\tarchive_tag_success=0;\n\tif [[ -f %s ]] && [[ -f %s ]]; then\n\t\tscp -p %s omega@%s:/Volumes/%sspace/Archive_Tags/READY_%s && archive_tag_success=1;\n\t\t%s;\n\tfi;\nfi',at_success_flag, success_flag, hf_success_flag,local_archive_tag,full_host_name,target_machine,volume_runno,write_archive_tag_success_cmd);
        
        
    if ~options.process_headfiles_only    
        if (starting_point <= 5)
            if ~options.keep_work
                % Send to workstation and write completion flag.
                %rm_previous_flag = sprintf('if [[ -f %s ]]; then rm %s; fi',fail_flag,fail_flag);
                t_images_dir = images_dir;
                %{
        while 1
            if strcmp(t_images_dir(end),'/')
                t_images_dir(end) = [];
            else
                break;
            end
        end
        %aa
                %}
                mkdir_cmd = sprintf('ssh omega@%s ''mkdir -p -m 777 /Volumes/%sspace/%s/%simages/''',full_host_name,target_machine,volume_runno,volume_runno);
                scp_cmd = sprintf('echo "Attempting to transfer data to %s.";scp -r %s omega@%s:/Volumes/%sspace/%s/ && success=1',target_machine,t_images_dir,full_host_name,target_machine,volume_runno);
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
                shipper_cmds{3}=sprintf('freespaceK=`ssh omega@%s ''df -k /Volumes/%sspace ''| tail -1 | xargs | cut -d '' '' -f4`', full_host_name,  target_machine);
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
                shipper_batch = [workdir 'sbatch/' volume_runno '_shipper.bash'];
                %batch_file = create_slurm_batch_files(shipper_batch,{rm_previous_flag,local_size_cmd remote_size_cmd eval_cmd},shipper_slurm_options);
                batch_file = create_slurm_batch_files(shipper_batch,shipper_cmds,shipper_slurm_options);
                dep_status='';
                if stage_4_running_jobs
                    dep_status='afterok-or';
                end
                stage_5_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_4_running_jobs,dep_status);
                %{
        if exist('continue_recon_enabled','var') && ~continue_recon_enabled
            clean_cmd_1 = ['rm -r ' work_subfolder];
            if exist(work_dir,'dir')
                %system(clean_cmd_1);
            end
        end
                %}
                %{
copy_archivetag_cmd = ['sshpass -p ' pw ' scp -p ' fullfile(images_dir,['READY_' volume_runno]) ...
    ' omega@' target_machine '.dhe.duke.edu:/Volumes/' target_machine 'space/Archive_Tags/READY_' volume_runno];
system(copy_archivetag_cmd);
disp('Finished!')
                %}
            end
        end
    end
    recon_type = 'CS_v2';
    if (starting_point <= 6)
        %opts=load(recon_file,'options');
        
        % Send a message that all recon is completed and has successfully
        % been sent to the target machine
        
        ship_cmd_0=sprintf('if [[ -f %s ]]; then\n\trm %s;\nfi',hf_fail_flag,hf_fail_flag);
        ship_cmd_1 = sprintf('ssh omega@%s ''if [[ ! -d /Volumes/%sspace/%s/ ]] ; then\n\t mkdir -m 777 /Volumes/%sspace/%s/;\nfi;''\nscp -p %s omega@%s:/Volumes/%sspace/%s/;',full_host_name,target_machine,volume_runno,target_machine,volume_runno,procpar_file,full_host_name,target_machine,volume_runno);
        ship_cmd_2 = sprintf('hf_success=0;\nssh omega@%s ''if [[ ! -d /Volumes/%sspace/%s/%simages/ ]] ; then\n\t mkdir -m 777 /Volumes/%sspace/%s/%simages/;\nfi '';\nscp -p %s omega@%s:/Volumes/%sspace/%s/%simages/ && hf_success=1',full_host_name,target_machine,volume_runno,volume_runno,target_machine,volume_runno, volume_runno,headfile,full_host_name,target_machine,volume_runno,volume_runno);
        write_hf_success_cmd = sprintf('if [[ $hf_success -eq 1 ]];\nthen\n\techo "Headfile transfer successful!"\n\ttouch %s;\nelse\n\ttouch %s; \nfi',hf_success_flag,hf_fail_flag);
        %archive_tag_cmd = '...';
        
        
        pp_running_jobs='';
        if ~(volume_number == n_volumes) && ~exist(procpar_file,'file')
            %{
            process_headfile_CS(recon_file,headfile,procpar_file,recon_type);
            log_mode=1;
            log_msg =sprintf('Procpar data for volume %s exists; Converting procpar information to headfile: %s.\n',volume_runno,headfile);
            yet_another_logger(log_msg,log_mode,log_file);
            system(ship_cmd_1);
            log_msg =sprintf('Volume %s: procpar file %s has been shipped to machine: %s.\n',volume_runno,procpar_file,target_machine);
            yet_another_logger(log_msg,log_mode,log_file);
            %ship_cmd = sprintf('ssh omega@%s.dhe.duke.edu ''if [[ ! -d /Volumes/%sspace/%s/ ]] ; then mkdir -m 777 /Volumes/%sspace/%s/;fi ''; scp %s omega@%s.dhe.duke.edu:/Volumes/%sspace/%s/',target_machine,target_machine,volume_runno,target_machine,volume_runno, headfile,target_machine,target_machine,volume_runno);
            system(ship_cmd_2);
            log_msg =sprintf('Volume %s: complete headfile %s has been shipped to machine: %s.\n',volume_runno,headfile,target_machine);
            yet_another_logger(log_msg,log_mode,log_file);
            %{
            copy_archivetag_cmd = ['sshpass -p ' pw ' scp -p ' fullfile(images_dir,['READY_' volume_runno]) ...
            ' omega@' target_machine '.dhe.duke.edu:/Volumes/' target_machine 'space/Archive_Tags/READY_' volume_runno];
            system(copy_archivetag_cmd);
            %}
            %}
            gk_slurm_options=struct;
            gk_slurm_options.v=''; % verbose
            gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
            gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount--or so I thought!.
            gk_slurm_options.p=gatekeeper_queue;
            %gk_slurm_options.job_name = [volume_runno '_procpar_gatekeeper'];
            gk_slurm_options.job_name = [runno '_procpar_gatekeeper_and_processor'];
            %gk_slurm_options.reservation = active_reservation;
            procpar_gatekeeper_batch = [workdir '/sbatch/' volume_runno '_procpar_gatekeeper.bash'];
            procpar_gatekeeper_cmd = sprintf('%s %s %s %s', procpar_gatekeeper_exec_path, matlab_path,procpar_file,log_file);
            batch_file = create_slurm_batch_files(procpar_gatekeeper_batch,procpar_gatekeeper_cmd,gk_slurm_options);
            pp_running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
        end
        ppcu_slurm_options=struct;
        ppcu_slurm_options.v=''; % verbose
        ppcu_slurm_options.s=''; % shared; volume manager needs to share resources.
        ppcu_slurm_options.mem=500; % memory requested; ppcu only needs a miniscule amount.
        ppcu_slurm_options.p='slow_master'; % For now, will use gatekeeper queue for volume manager as well
        %ppcu_slurm_options.job_name = [volume_runno '_procpar_cleanup'];
        ppcu_slurm_options.job_name = [runno '_procpar_gatekeeper_and_processor']; % Trying singleton dependency
        %ppcu_slurm_options.reservation = active_reservation;
        procpar_cleanup_batch = [workdir 'sbatch/' volume_runno '_procpar_cleanup.bash'];
        ppcu_cmd = sprintf('%s %s %s %s %s %s', procpar_cleanup_exec_path,matlab_path, recon_file,headfile,procpar_file,recon_type );
        dep_string ='';
        %if pp_running_jobs
        %   dep_string = 'afterok';
        %end
        if ~options.keep_work
            batch_file = create_slurm_batch_files(procpar_cleanup_batch,{ppcu_cmd ship_cmd_0 ship_cmd_1 ship_cmd_2 write_hf_success_cmd handle_archive_tag_cmd},ppcu_slurm_options);
            c_running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
            log_mode = 1;
            log_msg =sprintf('Procpar data for volume %s will be processed as soon as it is available; initializing gatekeeper (SLURM jobid(s): %s).\n',volume_runno,c_running_jobs);
            yet_another_logger(log_msg,log_mode,log_file);
        end
        
        if ~options.keep_work && ~options.process_headfiles_only
            %%%% Schedule cleanup
            
            trashman_slurm_options=struct;
            trashman_slurm_options.v=''; % verbose
            trashman_slurm_options.s=''; % shared; volume manager needs to share resources.
            trashman_slurm_options.mem=500; % memory requested; trashman only needs a miniscule amount.
            trashman_slurm_options.p='slow_master'; % For now, will use gatekeeper queue for volume manager as well
            %trashman_slurm_options.job_name = [volume_runno '_procpar_cleanup'];
            trashman_slurm_options.job_name = [volume_runno '_trashman']; % Trying singleton dependency
            %trashman_slurm_options.reservation = active_reservation;
            trashman_batch = [workdir 'sbatch/' volume_runno '_trashman.bash'];
            trashman_cmd = sprintf('if [[ -f "%s" ]]; then\n\tif [[ -d "%s" ]]; then\n\t\techo "Images have been successfully transferred; removing %s now...";\n\t\trm -rf %s;\n\telse\n\t\techo "Work folder %s already appears to have been removed. No action will be taken.";\n\tfi\nelse\n\techo "Images have not been successfully transferred yet; work folder will not be removed at this time.";\nfi', success_flag,work_subfolder,work_subfolder,work_subfolder,work_subfolder );
            dep_string ='';
            if stage_5_running_jobs
                dep_string = 'afterok-or';
            end
            batch_file = create_slurm_batch_files(trashman_batch,trashman_cmd, trashman_slurm_options);
            c_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_5_running_jobs ,dep_string);
            log_mode = 1;
            log_msg =sprintf('Once images for volume %s have been reconned and sent to %s, work folder %s will be removed via SLURM job(s): %s.\n',volume_runno,target_machine,work_subfolder,c_running_jobs);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    end
    if stage_4_running_jobs
        vm_slurm_options=struct;
        vm_slurm_options.v=''; % verbose
        vm_slurm_options.s=''; % shared; volume manager needs to share resources.
        vm_slurm_options.mem=512; % memory requested; vm only needs a miniscule amount.
        vm_slurm_options.p=cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
        vm_slurm_options.job_name = [volume_runno '_volume_manager'];
        %vm_slurm_options.reservation = active_reservation;
        volume_manager_batch = [workdir 'sbatch/' volume_runno '_volume_manager.bash'];
        vm_cmd = sprintf('%s %s %s %s %i %s', volume_manager_exec_path,matlab_path, recon_file,volume_runno, volume_number,base_workdir);
        batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
        c_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_4_running_jobs,'afternotok');
        log_mode = 1;
        log_msg =sprintf('If original cleanup jobs for volume %s fail, volume_manager will be re-initialized (SLURM jobid(s): %s).\n',volume_runno,c_running_jobs);
        yet_another_logger(log_msg,log_mode,log_file);
    end
end

