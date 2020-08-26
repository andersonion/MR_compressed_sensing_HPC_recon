function starting_point = volume_manager_exec(recon_file,volume_runno, volume_number,base_workdir)
% volume_manager_exec(recon_file,volume_runno, volume_number,base_workdir)
% Manages the  compressed sensing reconstruction of an independent 3D volume
% % Functions similarly to old code CS_recon_cluster_bj_multithread_v2[a]
%
%
% Written by BJ Anderson, CIVM
% 21 September 2017


% for all execs run this little bit of code which prints start and stop time using magic.
C___=exec_startup();

recon_mat=matfile(recon_file);
options=recon_mat.options;
log_mode=2;
if options.debug_mode>=10
    log_mode=1;
end
log_file=recon_mat.log_file;
try
    workdir=fullfile(base_workdir,volume_runno);
catch merr
    workdir=fullfile(recon_mat.agilent_study_workdir,volume_runno);
end
    
target_machine=options.target_machine;
target_host_name=sprintf('%s.dhe.duke.edu',target_machine);% This is a pretty stupid way to fix the unneccessary 'fix' James introduced
%full_host_name=databuffer.scanner_constants.scanner_host_name; % Just kidding. We can thank James for this red herring.

% Recon file should contain
%scale_file
%fid_tag_file
%dim_x,dim_y,dim_z
%scanner
%runno
%agilent_study
%agilent_series
% processed options
%options:
%target_machine
%fermi_filter (and w1/w2)
%chunk_size
%CS_recon_parameters: TVWeight,xfmWeight,Itnlim,wavelet_dims,wavelet_type
%% Reservation support
active_reservation=get_reservation(options.CS_reservation);
%% queue settings
cs_queue=CS_env_queue();
%% Executables support
% set an env var to get latest dev code, or will defacto run stable.
matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
cs_execs=CS_env_execs();
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

[starting_point, log_msg] = check_status_of_CSrecon(workdir,...
    volume_runno, ...
    recon_mat.scanner,...
    recon_mat.runno,...
    recon_mat.agilent_study,...
    recon_mat.agilent_series,...
    recon_mat.bbytes);
if ~islogical(options.CS_preview_data)
    if starting_point>2
        warning('CS_preview_data artificially reducing start point to 2');
        starting_point=2;
    end
end
yet_another_logger(log_msg,log_mode,log_file);
% Initialize a log file if it doesn't exist yet.
volume_log_file =fullfile(workdir, [volume_runno '_recon.log']);
if ~exist(volume_log_file,'file')
    system(['touch ' volume_log_file]);
end


setup_variables= fullfile(workdir,   [ volume_runno '_setup_variables.mat']);
images_dir =     fullfile(workdir,   [ volume_runno 'images']);
headfile =       fullfile(images_dir,[ volume_runno '.headfile']);

work_subfolder = fullfile(workdir, 'work');
temp_file =      fullfile(work_subfolder,[ volume_runno '.tmp']);
volume_fid =     fullfile(work_subfolder,[ volume_runno '.fid']);
volume_workspace = fullfile(work_subfolder, [volume_runno '_workspace.mat']);


hf_fail_flag=         fullfile(images_dir,sprintf('.%s_send_headfile_to_%s_FAILED',        volume_runno,target_machine));
hf_success_flag=      fullfile(images_dir,sprintf('.%s_send_headfile_to_%s_SUCCESSFUL',    volume_runno,target_machine));
fail_flag=            fullfile(images_dir,sprintf('.%s_send_images_to_%s_FAILED',          volume_runno,target_machine));
success_flag=         fullfile(images_dir,sprintf('.%s_send_images_to_%s_SUCCESSFUL',      volume_runno,target_machine));
at_fail_flag=         fullfile(images_dir,sprintf('.%s_send_archive_tag_to_%s_FAILED',     volume_runno,target_machine));
at_success_flag=      fullfile(images_dir,sprintf('.%s_send_archive_tag_to_%s_SUCCESSFUL', volume_runno,target_machine));

original_archive_tag= fullfile(images_dir,sprintf('READY_%s',volume_runno));
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
    % temporary patch to pull databuffer multi-struct out of the mat file.
    databuffer=recon_mat.databuffer;
    if ~exist(original_archive_tag,'file')
        write_archive_tag_nodev(volume_runno,['/' target_machine 'space'], ...
            recon_mat.dim_z,databuffer.headfile.U_code, ...
            '.raw',databuffer.headfile.U_civmid,true,images_dir);
    end
    system(sprintf('mv %s %s',original_archive_tag,local_archive_tag));
    clear databuffer;
end

if (starting_point == 0) ||  (  recon_mat.nechoes > 1 && starting_point == 1 && volume_number ~=1  )
    %% starting point 0/1
    % FID not ready yet, schedule gatekeeper for us.
    gk_slurm_options=struct;
    gk_slurm_options.v=''; % verbose
    gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
    gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount.
    gk_slurm_options.p=cs_queue.gatekeeper;
    %gk_slurm_options.job_name = [volume_runno '_gatekeeper'];
    gk_slurm_options.job_name = [recon_mat.runno '_gatekeeper']; %Trying out singleton behavior
    %gk_slurm_options.reservation = active_reservation;
    % using a blank reservation to force no reservation for this job.
    gk_slurm_options.reservation = '';
    agilent_study_gatekeeper_batch = fullfile(workdir, 'sbatch', [ volume_runno '_gatekeeper.bash']);
    [input_fid,~] =find_input_fidCS(recon_mat.scanner,recon_mat.runno,recon_mat.agilent_study,recon_mat.agilent_series);% hint: ~ ==> local_or_streaming_or_static
    gatekeeper_args= sprintf('%s %s %s %s %i %i', ...
        volume_fid, input_fid, recon_mat.scanner, log_file, volume_number, recon_mat.bbytes);
    gatekeeper_cmd = sprintf('%s %s %s ', cs_execs.gatekeeper, matlab_path,...
        gatekeeper_args);
    if ~options.live_run
        batch_file = create_slurm_batch_files(agilent_study_gatekeeper_batch,gatekeeper_cmd,gk_slurm_options);
        running_jobs = dispatch_slurm_jobs(batch_file,'','','singleton');
    else
        running_jobs='';
        eval(sprintf('gatekeeper_exec %s',gatekeeper_args));
    end
    vm_slurm_options=struct;
    vm_slurm_options.v=''; % verbose
    vm_slurm_options.s=''; % shared; volume manager needs to share resources.
    vm_slurm_options.mem=512; % memory requested; vm only needs a miniscule amount.
    vm_slurm_options.p=cs_queue.full_volume; % For now, will use gatekeeper queue for volume manager as well
    vm_slurm_options.job_name = [volume_runno '_volume_manager'];
    %vm_slurm_options.reservation = active_reservation;
    % using a blank reservation to force no reservation for this job.
    vm_slurm_options.reservation = '';
    volume_manager_batch = fullfile(workdir, 'sbatch', [ volume_runno '_volume_manager.bash']);
    vm_args=sprintf('%s %s %i %s',recon_file,volume_runno, volume_number,recon_mat.agilent_study_workdir);
    vm_cmd = sprintf('%s %s %s', cs_execs.volume_manager,matlab_path,vm_args);
    if ~options.live_run
        batch_file = create_slurm_batch_files(volume_manager_batch, ...
            vm_cmd,vm_slurm_options);
        or_dependency = '';
        if ~isempty(running_jobs)
            or_dependency='afterok-or';
        end
        c_running_jobs = dispatch_slurm_jobs(batch_file,'',...
            running_jobs,or_dependency);
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
        if starting_point<4
            [input_fid, local_or_streaming_or_static]=find_input_fidCS( ...
                recon_mat.scanner, recon_mat.runno, ...
                recon_mat.agilent_study, recon_mat.agilent_series);
        else
            input_fid='BOGUS_INPUT_FOR_DONE_WORK';
            local_or_streaming_or_static=3;
        end
        %% STAGE1 Scheduling
        if (starting_point <= 1 || ~islogical(options.CS_preview_data) )
            if ~exist('volume_fid','var')
                error('Confusing code path error on volume_fid reset');
                % volume_fid = [work_subfolder '/' volume_runno '.fid'];
            end
            % when checking consistency, we only check volume 1
            % That is becuase we're making sure the fid is what we expect,
            % and that is a reasonable fingerprint.
            % Checking other volumes would require getting their data bits
            % first, and that is not likely to fail independently.
            if (local_or_streaming_or_static == 1)
                fid_consistency = write_or_compare_fid_tag(input_fid,recon_mat.fid_tag_file,1);
            else
                scanner_user='omega';
                fid_consistency = write_or_compare_fid_tag(input_fid,recon_mat.fid_tag_file,1,recon_mat.scanner,scanner_user);
            end
            if fid_consistency
                %{
                % James commented this out because it was killing streaming CS,
                % when streaming data.
                % This code needs to be put someplace correct!
                if ~exist(procpar_file,'file')
                    datapath=['/home/mrraw/' agilent_study '/' agilent_series '.fid'];
                    mode =2; % Only pull procpar file
                    puller_glusterspaceCS_2(runno,datapath,scanner,recon_mat.agilent_study_workdir,mode);
                end
                %}
                % Getting subvolume should be the job of volume setup.
                % TODO: Move get vol code into setup!
                
                % HACK to allow preview post reconstruction cleanup.
                % work_subfolder = fileparts(volume_fid)
                if ~exist(work_subfolder,'dir')
                    warning('  Creating work subfolder to fetch fid, this shouldn''t happen here. This only occurs in exotic testing or recovery conditions.');
                    mkdir(work_subfolder);
                end
                if recon_mat.nechoes == 1
                    % for multi-block fids(diffusion)
                    if (local_or_streaming_or_static == 1)
                        get_subvolume_from_fid(input_fid,volume_fid,volume_number,recon_mat.bbytes);
                    else
                        get_subvolume_from_fid(input_fid,volume_fid,volume_number,recon_mat.bbytes,recon_mat.scanner,scanner_user);
                    end
                elseif recon_mat.nechoes > 1 && volume_number == 1
                    % for 1 block fids, mgre, and single vol, in theory we
                    % can only operate when static, further we should only
                    % enter this code block if already static.
                    %
                    % This is coded to only trigger for multi-echo,
                    % Hopefully single vol will be handled correctly in necho 1 block above.
                    %
                    % schedule local gatekeeper on volume fid
                    % for volume 1 fetch fetch data, run the fid
                    % splitter.
                    
                    % due to how ugly puller_glusterpsaceCS_2 is we have to define yet another temply var.
                    % hopefully we can swap the proper terminal puller code
                    if ~exist('datapath','var')
                        datapath=['/home/mrraw/' recon_mat.agilent_study '/' recon_mat.agilent_series '.fid'];
                    end
                    local_fid= fullfile(recon_mat.agilent_study_workdir,'fid');
                    if ~exist(local_fid,'file')
                        puller_glusterspaceCS_2(recon_mat.runno,datapath,recon_mat.scanner,recon_mat.agilent_study_workdir,3);
                    end
                    if ~exist(local_fid,'file') 
                        % It is assumed that the target of puller is the local_fid
                        error_flag = 1;
                        log_msg =sprintf('Unsuccessfully attempt to pull file from scanner %s: %s. Dying now.\n',...
                            scanner,[datapath '/fid']);
                        yet_another_logger(log_msg,log_mode,log_file,error_flag);
                        if isdeployed
                            quit force;
                        else
                            error(log_msg);
                        end
                    end
                    % Run splitter
                    fs_slurm_options=struct;
                    fs_slurm_options.v=''; % verbose
                    fs_slurm_options.s=''; % shared; volume setup should to share resources.
                    fs_slurm_options.mem=50000; % memory requested; fs needs a significant amount; could do this smarter, though.
                    fs_slurm_options.p=cs_queue.full_volume; % For now, will use gatekeeper queue for volume manager as well
                    fs_slurm_options.job_name = [recon_mat.runno '_fid_splitter_recon'];
                    fs_slurm_options.reservation = active_reservation;
                    fs_args= sprintf('%s %s', local_fid,recon_file);
                    fs_cmd = sprintf('%s %s %s', cs_execs.fid_splitter,matlab_path,fs_args);
                    if ~options.live_run
                        fid_splitter_batch = [workdir '/sbatch/' recon_mat.runno '_fid_splitter_CS_recon.bash'];
                        batch_file = create_slurm_batch_files(fid_splitter_batch,fs_cmd,fs_slurm_options);
                        %fid_splitter_running_jobs
                        stage_1_running_jobs = dispatch_slurm_jobs(batch_file,'');
                    else
                        eval(sprintf('fid_splitter_exec %s',fs_args));
                    end
                else
                    error('Trouble with nechoes detect switch tell dev they''re sloppy');
                end
            else
                log_mode = 1;
                error_flag = 1;
                log_msg = sprintf('Fid consistency failure at volume %s! source fid for (%s) is not the same source fid as the first volume''s fid.\n',volume_runno,input_fid);
                log_msg = sprintf('%sCan manual check with "write_or_compare_fid_tag(''%s'',''%s'',%i,''%s'',''%s'')"\n',...
                    log_msg,input_fid,fid_tag_file,volume_number,recon_mat.scanner,scanner_user);
                log_msg = sprintf('%sCRITICAL ERROR local_or_streaming_or_static=%i\n',log_msg,local_or_streaming_or_static);
                
                yet_another_logger(log_msg,log_mode,log_file,error_flag);
                if isdeployed
                    quit force;
                else
                    error(log_msg);
                end
            end
        end
        %% STAGE2 Scheduling
        if (starting_point <= 2 || ~islogical(options.CS_preview_data) )
            % Schedule setup
            %% Make variable file
            mf = matfile(setup_variables,'Writable',true);
            mf.recon_file = recon_file;
            mf.volume_number=volume_number;
            mf.volume_runno = volume_runno;
            mf.work_subfolder = work_subfolder;
            mf.volume_log_file = volume_log_file;
            %{
            mf.procpar_file = procpar_file;
            mf.scale_file = scale_file;
            %}
            mf.volume_fid = volume_fid;
            mf.volume_workspace = volume_workspace;
            mf.workdir = workdir;
            mf.temp_file = temp_file;
            mf.images_dir =images_dir;
            mf.headfile = headfile;
            %{
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
            %}
            %% Schedule setup via slurm and record jobid for dependency scheduling.
            vsu_slurm_options=struct;
            vsu_slurm_options.v=''; % verbose
            vsu_slurm_options.s=''; % shared; volume setup should to share resources.
            vsu_slurm_options.mem=50000; % memory requested; vsu needs a significant amount; could do this smarter, though.
            vsu_slurm_options.p=cs_queue.full_volume; % For now, will use gatekeeper queue for volume manager as well
            vsu_slurm_options.job_name = [volume_runno '_volume_setup_for_CS_recon'];
            %vsu_slurm_options.reservation = active_reservation;
            % using a blank reservation to force no reservation for this job.
            vsu_slurm_options.reservation = '';
            volume_setup_batch = fullfile(workdir, 'sbatch', [ volume_runno '_volume_setup_for_CS_recon.bash']);
            vsu_args=sprintf('%s %i',setup_variables, volume_number);
            vsu_cmd = sprintf('%s %s %s', cs_execs.volume_setup,matlab_path, vsu_args);
            if  stage_1_running_jobs
                dep_string = stage_1_running_jobs;
                dep_type = 'afterok-or';
            else
                dep_string = '';
                dep_type = '';
            end
            if ~options.live_run
                batch_file = create_slurm_batch_files(volume_setup_batch,vsu_cmd,vsu_slurm_options);
                stage_2_running_jobs = dispatch_slurm_jobs(batch_file,'',dep_string,dep_type);
            else
                eval(sprintf('setup_volume_work_for_CSrecon_exec %s',vsu_args));
            end
        end
        if options.CS_preview_data
            return;
        end
        %% STAGE3 Scheduling
        if (starting_point <= 3)
            %{
            % update itnlim from main mat file to our volume file...
            % but SERIOUSLY WHY!
            mf = matfile(variables_file,'Writable',true);
            rf = matfile(recon_file);
            rf_opts=rf.options;
            Itnlim = rf_opts.Itnlim;
            mf_opts=mf.options;
            mf_opts.Itnlim=Itnlim;
            mf.options=mf_opts;
            %}
            % Schedule slice jobs
            single_threaded_recon =1;
            swr_slurm_options=struct;
            swr_slurm_options.v=''; % verbose
            if single_threaded_recon
                swr_slurm_options.c=1; % was previously 2...also need to investigate binding
                swr_slurm_options.hint='nomultithread';
                %{
            else
                swr_slurm_options.s='';
                swr_slurm_options.hint='multithread';
                %}
            end
            % We use mem limit to control the number of jobs per node.
            % Want to allow 32-40 jobs per node, but use --ntasks-per-core=1
            % to make sure that every core has exactly one job on them.
            % That is why this mem number gets to be constant, we shouldnt
            % run into trouble until CS_slices are very (VERY) large.
            swr_slurm_options.mem='5900';
            swr_slurm_options.p=cs_queue.recon;
            % swr_slurm_options.job_name=[volume_runno '_CS_recon_' num2str(chunk_size) '_slice' plural '_per_job'];
            swr_slurm_options.job_name=[volume_runno '_CS_recon_NS' num2str(options.chunk_size)];
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
                            slices_to_process = find(tmp_header<options.Itnlim);
                        end
                    end
                    if isempty(slices_to_process)
                        slices_to_process = 0;
                    end
                else
                    slices_to_process =1:1:recon_mat.original_dims(1,1);
                end
            else
                slices_to_process = 1:1:recon_mat.original_dims(1,1);
            end
            
            if slices_to_process
                num_chunks = ceil(length(slices_to_process)/options.chunk_size);
                log_msg =sprintf('Volume %s: Number of chunks (independent jobs): %i.\n',volume_runno,num_chunks);
                yet_another_logger(log_msg,log_mode,log_file);
                log_msg =sprintf('Volume %s: Number of slices to be reconstructed: %i.\n',volume_runno,nnz(~isnan(slices_to_process)));
                yet_another_logger(log_msg,log_mode,log_file);
                
                % pad slices_to_process out to num_chunks*chunk_size if not
                % even multiple.
                slice_pack_padding=options.chunk_size-mod(numel(slices_to_process),options.chunk_size);
                if slice_pack_padding~=options.chunk_size
                    slices_to_process(end+1:end+slice_pack_padding)=NaN;
                end
                
                s3jobs=cell(1,num_chunks);
                %slices to process would be better named chunks, or slabs.
                slices_to_process = reshape(slices_to_process,[options.chunk_size num_chunks]);
                % slice in this for loop would be better named chunk, or
                % slab
                % we could parfor this when we're in live_mode.
                zero_width = ceil(log10((recon_mat.dim_x+1)));
                for ch_num=1:num_chunks
                    %parfor ch_num=1:num_chunks
                    sx=slices_to_process(:,ch_num);
                    slice_string = sprintf(['' '%0' num2str(zero_width) '.' num2str(zero_width) 's'] ,num2str(sx(1)));
                    sx(isnan(sx))=[];
                    if length(sx)>3
                        no_con_test = sum(diff(diff(sx)));
                    else
                        no_con_test = 1;
                    end
                    for ss = 2:length(sx)
                        if (no_con_test)
                            slice_string = [slice_string '_' sprintf(['' '%0' num2str(zero_width) '.' num2str(zero_width) 's'] ,num2str(sx(ss)))];
                        elseif (ss==length(sx))
                            slice_string = [slice_string '_to_' sprintf(['' '%0' num2str(zero_width) '.' num2str(zero_width) 's'] ,num2str(sx(ss)))];
                        end
                    end
                    slicewise_recon_batch = fullfile(workdir, 'sbatch', [ volume_runno '_slice' slice_string '_CS_recon.bash']);
                    swr_args= sprintf('%s %s %s', volume_workspace, slice_string,setup_variables);
                    swr_cmd = sprintf('%s %s %s', cs_execs.slice_recon,matlab_path,swr_args);
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
                        s3jobs{ch_num}=c_running_jobs;
                        if msg1
                            disp(msg1)
                        end
                        if msg2
                            disp(msg2)
                        end
                    else
                        %eval(sprintf('slicewise_CSrecon_exec %s',swr_args));
                        slicewise_CSrecon_exec( volume_workspace, slice_string,setup_variables);
                        %slicewise_CSrecon_exec(swr_args)
                        %starting_point=4;
                    end
                end
                stage_3_running_jobs=strjoin(s3jobs,':');
                if strcmp(':',stage_3_running_jobs(1))
                    stage_3_running_jobs(1)=[];
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
            local_archive_tag,getenv('USER'),target_host_name,target_machine,volume_runno,write_archive_tag_success_cmd);
        vol_mat = matfile(setup_variables,'Writable',true);
        vol_mat.handle_archive_tag_cmd=handle_archive_tag_cmd;
        %% STAGE4 Scheduling
        if (starting_point <= 4)
            %% Schedule via slurm and record jobid for dependency scheduling.
            vcu_slurm_options=struct;
            vcu_slurm_options.v=''; % verbose
            vcu_slurm_options.s=''; % shared; volume setup should to share resources.
            vcu_slurm_options.mem=66000; % memory requested; vcu needs a significant amount; could do this smarter, though.
            vcu_slurm_options.p=cs_queue.full_volume; % Really want this to be high_priority, and will usually be that.
            vcu_slurm_options.job_name =[volume_runno '_CS_recon_NS' num2str(options.chunk_size)];
            %vcu_slurm_options.reservation = active_reservation;
            % using a blank reservation to force no reservation for this job.
            vcu_slurm_options.reservation = ''; 
            volume_cleanup_batch = fullfile(workdir, 'sbatch', [ volume_runno '_volume_cleanup_for_CS_recon.bash']);
            vcu_args=sprintf('%s',setup_variables);
            vcu_cmd = sprintf('%s %s %s', cs_execs.volume_cleanup,matlab_path,vcu_args);
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
                    getenv('USER'),target_host_name,target_machine,volume_runno,volume_runno);
                scp_cmd = sprintf(['echo "Attempting to transfer data to %s.";' ...
                    'scp -pr %s %s@%s:/Volumes/%sspace/%s/ && success=1'], ...
                    target_machine,t_images_dir,getenv('USER'),target_host_name,target_machine,volume_runno);
                write_success_cmd = sprintf('if [[ $success -eq 1 ]];\nthen\n\techo "Transfer successful!"\n\ttouch %s;\nelse\n\ttouch %s; \nfi',success_flag,fail_flag);
                %{
                local_size_cmd = sprintf('gimmespaceK=`du -cks %s | tail -n 1 | xargs |cut -d '' '' -f1`',images_dir);
                remote_size_cmd = sprintf('freespaceK=`ssh omega@%s.dhe.duke.edu ''df -k /Volumes/%sspace ''| tail -1 | cut -d '' '' -f5`',target_machine,target_machine);
                eval_cmd = sprintf(['success=0;\nif [[ $freespaceK -lt $gimmespaceK ]]; then\n\techo "ERROR: not enough space to transfer %s to %s; $gimmespaceK K needed, but only $freespaceK K available."; '...
               'else %s; fi; %s'],  images_dir,target_machine, scp_cmd,write_success_cmd);
                %}
                n_raw_images = recon_mat.dim_z;
                shipper_cmds{1}=sprintf('success=0;\nc_raw_images=$(ls %s | grep raw | wc -l | xargs); if [[ "${c_raw_images}"  -lt "%i" ]]; then\n\techo "Not all %i raw images have been written (${c_raw_images} total); no images will be sent to remote machine.";\nelse\nif [[ -f %s ]]; then\n\trm %s;\nfi',images_dir,n_raw_images,n_raw_images,fail_flag,fail_flag);
                shipper_cmds{2}=sprintf('gimmespaceK=`du -cks %s | tail -n 1 | xargs |cut -d '' '' -f1`',images_dir);
                shipper_cmds{3}=sprintf('freespaceK=`ssh %s@%s ''df -k /Volumes/%sspace ''| tail -1 | xargs | cut -d '' '' -f4`', getenv('USER'), target_host_name,  target_machine);
                shipper_cmds{4}=sprintf('if [[ $freespaceK -lt $gimmespaceK ]];');
                shipper_cmds{5}=sprintf('then\n\techo "ERROR: not enough space to transfer %s to %s; $gimmespaceK K needed, but only $freespaceK K available."',images_dir,target_machine);
                shipper_cmds{6}=sprintf('else\n\t%s;\n\t%s;\nfi',mkdir_cmd,scp_cmd);
                shipper_cmds{7}=sprintf('fi\n%s',write_success_cmd);
                shipper_cmds{8}=sprintf('%s',handle_archive_tag_cmd);
                shipper_slurm_options=struct;
                shipper_slurm_options.v=''; % verbose
                shipper_slurm_options.s=''; % shared; volume manager needs to share resources.
                shipper_slurm_options.mem=500; % memory requested; shipper only needs a miniscule amount.
                shipper_slurm_options.p=cs_queue.gatekeeper; % For now, will use gatekeeper queue for volume manager as well
                shipper_slurm_options.job_name = [volume_runno '_ship_to_' target_machine];
                %shipper_slurm_options.reservation = active_reservation;
                % using a blank reservation to force no reservation for this job.
                shipper_slurm_options.reservation = '';
                shipper_batch = fullfile(workdir, 'sbatch', [ volume_runno '_shipper.bash']);
                %batch_file = create_slurm_batch_files(shipper_batch,{rm_previous_flag,local_size_cmd remote_size_cmd eval_cmd},shipper_slurm_options);
                if ~exist(success_flag,'file')
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
                else
                    ship_st=0;
                    fprintf('Images previously sent successfully.\n');
                end
                %% STAGE5+ Scheduling
                %if (starting_point >= 5)%(starting_point <= 6)
                if (starting_point == 5)%(starting_point <= 6)
                    % This is only scheduled at stage 5 because prior to that it wont
                    % work anyway.
                    %if ~options.live_run
                        stage_5e_running_jobs = deploy_procpar_handlers(setup_variables);
                    %else
                        %% live run starting point advance handling
                        % this prevents volume manager from running
                        % recursively forever.
                        if options.live_run && exist('ship_st','var')
                            if ship_st==0
                                starting_point=6;
                            end
                        end
                    %end
                end
            end
        end
    end
    % Why is volume manager only re-scheduled if we have stage 4(cleanup)
    % jobs? That seems like a clear mistake! We should be rescheduling so
    % long as we're not stage 6. 
    % AND we should be dependent on all the rest of the jobs having
    % terminated eg, dependency=afterany. SO, we should update this code to
    % build a running list of jobs to be scheduled behind. `
    %if stage_4_running_jobs
    % when we keep work, we never finish stage 5 because we never send
    % data.
    % That seems okay, so lets watch for that, and not re_schedule volume
    % manager when keep_work is on and stage is 5+
    %{
    if ( ~options.keep_work && starting_point < 6 ) ...
            || ( options.keep_work &&  starting_point < 5 )
    %}
    % clever simplificaion of conditional.
    if starting_point < ( 6 - options.keep_work)
        vm_slurm_options=struct;
        vm_slurm_options.v=''; % verbose
        vm_slurm_options.s=''; % shared; volume manager needs to share resources.
        vm_slurm_options.mem=2048; % memory requested; vm only needs a miniscule amount.
            %--In theory only! For yz-array sizes > 2048^2, loading the
            % data of phmask, CSmask, etc can push the memory of 512 MB
        vm_slurm_options.p=cs_queue.full_volume; % For now, will use gatekeeper queue for volume manager as well
        vm_slurm_options.job_name = [volume_runno '_volume_manager'];
        %vm_slurm_options.reservation = active_reservation;
        % using a blank reservation to force no reservation for this job.
        vm_slurm_options.reservation = '';
        volume_manager_batch = fullfile(workdir, 'sbatch', [ volume_runno '_volume_manager.bash']);
        vm_args=sprintf('%s %s %i %s',recon_file,volume_runno, volume_number,recon_mat.agilent_study_workdir);
        vm_cmd = sprintf('%s %s %s', cs_execs.volume_manager,matlab_path, vm_args);
        if ~options.live_run
            batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
            %{
            if stage_4_running_jobs
                c_running_jobs = dispatch_slurm_jobs(batch_file,'',stage_4_running_jobs,'afternotok');
            elseif stage_5_running_jobs
            end
            %}
            %% re-configured to run as singleton unless we scheduled endstage jobs. 
            % when we schecdule end stage jobs, tell ourselves to run one
            % more time once they're terminated, note not after failure, or
            % after success.
            dep_type='singleton';
            dep_jobs='';
            if ~isempty(stage_4_running_jobs) || ~isempty(stage_5_running_jobs) || ~isempty(stage_5e_running_jobs)
                dep_type='afterany';
                %%% these can be combined with strjoin. 
                job_glob=cell(0);
                if stage_5e_running_jobs
                    job_glob=[job_glob,stage_5e_running_jobs];
                    %dep_jobs=stage_5e_running_jobs;
                end
                if stage_5_running_jobs
                    job_glob=[job_glob,stage_5_running_jobs];
                    %dep_jobs=sprintf('%s:%s',dep_jobs,stage_5_running_jobs);
                end
                if stage_4_running_jobs
                    job_glob=[job_glob,stage_4_running_jobs];
                    %dep_jobs=sprintf('%s:%s',dep_jobs,stage_4_running_jobs);
                end
                %{
                if strcmp(dep_jobs(1),':')
                    dep_jobs(1)=[];
                end
                %}
                dep_jobs=strjoin(job_glob,':');
            end
            c_running_jobs = dispatch_slurm_jobs(batch_file,'',dep_jobs,dep_type);
            log_mode = 1;
            log_msg =sprintf('If original cleanup jobs for volume %s fail, volume_manager will be re-initialized (SLURM jobid(s): %s).\n',volume_runno,c_running_jobs);
            yet_another_logger(log_msg,log_mode,log_file);
        else
            % could add dbstack check to prevent infinite recursion and
            % stack overflow like behavior.
            % maybe max out at 50? 
            eval(sprintf('volume_manager_exec %s',vm_args));
            pause(1);
        end
    end
    if starting_point == 6
        volume_clean(setup_variables);
    end
end

