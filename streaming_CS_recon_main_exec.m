function streaming_CS_recon_main_exec(scanner,runno,study,agilent_series, CS_table, varargin )
%  Initially created on 14 September 2017, BJ Anderson, CIVM
%% SUMMARY
%  Main code for compressed sensing reconstruction on a computing cluster
%  running SLURM Version 2.5.7, with data originating from Agilent MRI scanners
%  running VnmrJ Version 4.0_A.
%
%  The primary new feature of this version versus previous versions is the
%  ability to stream multi-volume experiments so each independent volume
%  can be reconstructed as soon as it's data has been acquired (previously,
%  one had to wait until the entire scan finished before beginning
%  reconstruction).  This is particularly useful for Diffusion Tensor
%  Imaging (DTI) scans. Gradient-Recalled Echo (GRE) scans and their
%  cousin Multiple echo GRE (MGRE) scans will be indifferent to this
%  change, as they can only be reconstructed once the scan has completely
%  finished.
%
%
%
%

if ~isdeployed
   addpath('/cm/shared/workstation_code_dev/recon/CS_v2/sparseMRI_v0.2/utils/'); 
end

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

%% Determine where the matlab executables live
%  May change this to look to environment variables, or a seperate
%  head/textfile, which will give us dynamic flexibility if our goal is
%  have end-to-end deployability.
matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
% Gatekeeper support
gatekeeper_exec = getenv('CS_GATEKEEPER_EXEC');
% set an env var to get latest dev code, or will defacto run stable. 
CS_CODE_DEV=getenv('CS_CODE_DEV');
if isempty(CS_CODE_DEV)
    CS_CODE_DEV='stable';
end
if isempty(gatekeeper_exec)
    %gatekeeper_exec = '/cm/shared/workstation_code_dev/matlab_execs/gatekeeper_executable/20171004_1111/run_gatekeeper_exec.sh';
    %gatekeeper_exec = '/cm/shared/workstation_code_dev/matlab_execs/gatekeeper_executable/stable/run_gatekeeper_exec.sh';
    gatekeeper_exec = [ '/cm/shared/workstation_code_dev/matlab_execs/gatekeeper_executable/' CS_CODE_DEV '/run_gatekeeper_exec.sh'] ;
    setenv('CS_GATEKEEPER_EXEC',gatekeeper_exec);
end

gatekeeper_queue = getenv('CS_GATEKEEPER_QUEUE');
if isempty(gatekeeper_queue)
    gatekeeper_queue =  'slow_master';%'high_priority';
    setenv('CS_GATEKEEPER_QUEUE',gatekeeper_queue)
end

cs_full_volume_queue = getenv('CS_FULL_VOLUME_QUEUE');
if isempty(cs_full_volume_queue)
    cs_full_volume_queue = 'high_priority';
end

fid_splitter_exec = getenv('CS_FID_SPLITTER_EXEC');
if isempty(fid_splitter_exec)
    %fid_splitter_exec = '/cm/shared/workstation_code_dev/matlab_execs/fid_splitter_executable/20171026_1718/run_fid_splitter_exec.sh';   
    fid_splitter_exec = [ '/cm/shared/workstation_code_dev/matlab_execs/fid_splitter_executable/' CS_CODE_DEV '/run_fid_splitter_exec.sh' ];

    setenv('CS_FID_SPLITTER_EXEC',fid_splitter_exec);
end

volume_manager_exec = getenv('CS_VOLUME_MANAGER_EXEC');
if isempty(volume_manager_exec)
    %volume_manager_exec = '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/20171003_1013/run_volume_manager_exec.sh';
    %volume_manager_exec = '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/20171023_1647//run_volume_manager_exec.sh'; % Sills version
    %volume_manager_exec = '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/20171031_1006/run_volume_manager_exec.sh'; % Sills version
    volume_manager_exec = [ '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/' CS_CODE_DEV '/run_volume_manager_exec.sh'];
    setenv('CS_VOLUME_MANAGER_EXEC',volume_manager_exec);
end
%% Current defaults--option handling will be upgraded shortly
if ~exist('target_machine','var')
    target_machine = 'delos';
end
if ~exist('fermi_filter','var')
    fermi_filter=1; %Changing the fermi_filter default to ON
end
if ~exist('chunk_size','var')
    chunk_size=6; % 25 November 2016, temporarily (?) changed to 6
end
if ~exist('CS_recon_params','var')
    CS_recon_params=''; % Added 23 December 2016 or otherwise default values won't work. --BJA
end
%%  Option Handling (goes here)
options = struct;% options_handler(varargin{:}); % Check name and syntax later.
% James, here are the OPTIONS (thus far):
% target_machine (string)
% fermi_filter (boolean)
% fermi_w1 (float)
% fermi_w2 (float)
% TVweight (float)
% xfmWeight (float)
% max_iterations (positive integer) [formerly Itnlim]
% convergence_threshold (float)
% wavelet_dims
% wavelet_type
% chunk_size

% TEMPORARY, until options are fully implemented
if exist('CS_table','var')
    if length(CS_table)>4
        options.CS_table=CS_table;
        if exist('varargin','var') && numel(varargin)>=1
            Itnlim=str2double(varargin{1});
        else
            Itnlim = 98;
        end
    else
        Itnlim=str2double(CS_table);
    end
else
    options.CS_table=0;
    Itnlim = 98;
end
options.verbose=1;
%

log_mode = 2; % Log only to log file.
if options.verbose
    log_mode = 1; % Log to file and standard out/error.
end

if ~ischar(agilent_series)
    agilent_series = num2str(agilent_series);
    if length(agilent_series) < 2
        agilent_series = ['0' agilent_series];
    end
    agilent_series = ['ser' agilent_series];
end


%%  cd /cm/shared/workstation_code_dev/shared/pipeline_utilities
%addpath(genpath('/home/rmd22/Documents/MATLAB/'));

%% Get all necessary code for reconstruction
% addpath('/cm/shared/workstation_code/shared/mathworks/slurm_shared');
% addpath('/cm/shared/workstation_code/shared/civm_matlab_common_utils');
% addpath('/cm/shared/workstation_code/shared/mathworks/dirrec');
% addpath('/cm/shared/workstation_code/recon/mat_recon_pipe/mat_wrappers');
% addpath('/cm/shared/workstation_code/shared/mathworks/dlmcell');
% addpath('/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/');
% addpath('/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/sparseMRI_v0.2');
% addpath('/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850');

%% Input checks

scratch_drive = getenv('BIGGUS_DISKUS'); % Currently, this is /glusterspace.
workdir = fullfile(scratch_drive,[runno '.work/']);
%end

if ~exist(workdir,'dir');
    mkdir_cmd = sprintf('mkdir -m 777 %s',workdir);
    system(mkdir_cmd);
end
% Initialize a log file if it doesn't exist yet.
log_file = [workdir '/' runno '.recon_log'];
if ~exist(log_file,'file')
    system(['touch ' log_file]);
end
% Write initialization info to log file.
ts=fix(clock);
t=datetime(ts(1:3));
month_string = month(t,'name');
start_date=sprintf('%02i %s %04i',ts(3),month_string{1},ts(1));
start_time=sprintf('%02i:%02i',ts(4:5));

user = getenv('USER');

log_msg =sprintf('\n----------\nCompressed sensing reconstruction initialized on: %s at %s.\n----------\nScanner runno: %s.\nScanner series: %s\nUser: %s\n',start_date, start_time, study, agilent_series,user);
yet_another_logger(log_msg,log_mode,log_file);

local_fid=[workdir runno '.fid'];
input_fid=''; % Initialize input_fid

% Check to see if a flag_file for complete recon exists
study_flag = [workdir '/.' runno '.recon_completed'];
if ~exist(study_flag,'file')
    
    %% First things first: get specid from user!

    % Create reconfile
    recon_file = [workdir runno 'recon.mat'];
    if ~exist(recon_file,'file')
        recon_file = specid_to_recon_file(scanner,runno,recon_file);
    end
    
    %% Second First things first: determine number of volumes to be reconned
    
    local_hdr = [workdir runno '_hdr.fid'];
        
    %{
    [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,series);
    
    if (local_or_streaming_or_static == 2)
        % Need to fix! This will incorrectly say it is streaming if
        % original fid is moved!
        log_msg =sprintf('WARNING: Inputs not found locally or on scanner; running in streaming mode.\n');
        yet_another_logger(log_msg,log_mode,log_file);
    end
    %}
    
    if ~exist(local_hdr,'file');
        [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
        
        if (local_or_streaming_or_static == 2)
            log_msg =sprintf('WARNING: Inputs not found locally or on scanner; running in streaming mode.\n');
            yet_another_logger(log_msg,log_mode,log_file);
        end
        
        
        if (local_or_streaming_or_static == 1)
            get_hdr_from_fid(input_fid,local_hdr);
        else
            get_hdr_from_fid(input_fid,local_hdr,scanner);
        end
    end
    [npoints,nblocks,ntraces,bitdepth,bbytes,~,~] = load_fid_hdr_details(local_hdr);
    dim_x = round(npoints/2);
    procpar_file = [workdir runno '.procpar'];
    procpar_or_CStable= procpar_file;
    if ~exist(procpar_file,'file')
        if ~exist('local_or_streaming_or_static','var')
            [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
        end
        if (local_or_streaming_or_static == 2)
            tables_in_workdir=dir([workdir '/CS*_*x*_*']);
            if (isempty(tables_in_workdir))
                if (~options.CS_table)
                    %options.CS_table = input('Please enter the name of the CS table used for this scan.','s');
                    pull_table_cmd = [ 'ssh omega@' scanner ' ''cd /home/vnmr1/vnmrsys/tablib/; ls CS*_*x_*'''];
                    status = 1;
                    [status,available_tables]=system(pull_table_cmd);
                    if status
                        %error_flag=1;
                        log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
                        %yet_another_logger(log_msg,log_mode,log_file,error_flag);
                        disp(log_msg)
                        error_due_to_network_issues
                        %quit
                    end
                    
                    %[~,available_tables]=system(pull_table_cmd);
                    
                    log_msg = sprintf('Please rerun this code and specify the CS_table to run in streaming mode (otherwise you will need to wait until the entire scan completes).\nAvailable tables:\n%s\n',available_tables);
                    %procpar_or_CStable=[workdir options.CS_table];        
                    yet_another_logger(log_msg,log_mode,log_file,1);
                    if isdeployed
                        quit force;
                    end
                end
                log_msg = sprintf('Per user specification, using CS_table ''%s''.\n',options.CS_table);
            else
                 options.CS_table=tables_in_workdir(1).name;
                 log_msg = sprintf('Using first CS_table found in work directory: ''%s''.\n',options.CS_table);           
            end
            procpar_or_CStable=[workdir options.CS_table];        
            yet_another_logger(log_msg,log_mode,log_file);
            
        else
            datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
            mode =2; % Only pull procpar file
            puller_glusterspaceCS_2(runno,datapath,scanner,workdir,mode);
        end
    end
        
    %% Might as well process skiptable/mask while we're here
    [dim_y, dim_z, n_sampled_lines,sampling_fraction,mask,CSpdf,phmask,recon_dims,original_mask,original_pdf,original_dims] = process_CS_mask(procpar_or_CStable,dim_x);
        
    %%
    nechoes = 1;
    if (nblocks == 1)
        nechoes = round(ntraces/n_sampled_lines); % Shouldn't need to round...just being safe.
        n_volumes = nechoes;
    else
        n_volumes = nblocks;
    end
        
    %% Check all n_volumes for incomplete reconstruction
    %unreconned_volumes = 0;
    unreconned_volumes=[];
    unreconned_volumes_strings={};
    
    reconned_volumes=[];
    reconned_volumes_strings={};
    
    for volume_number = 1:n_volumes;
        vol_string =sprintf(['%0' num2str(numel(num2str(n_volumes-1))) 'i' ],volume_number-1);
        volume_runno = sprintf('%s_m%s',runno,vol_string);
        %volume_flag = [workdir '/' runno '_m' vol_string '/.' runno '_m' vol_string '.recon_completed'];
        volume_flag=sprintf('%s/%s/%simages/.%s_send_archive_tag_to_%s_SUCCESSFUL', workdir,volume_runno,volume_runno,volume_runno,target_machine);
        if ~exist(volume_flag,'file')
            unreconned_volumes = [ unreconned_volumes volume_number ]; 
            unreconned_volumes_strings{length(unreconned_volumes_strings)+1}=vol_string;
        else
            reconned_volumes = [ reconned_volumes volume_number ]; 
            reconned_volumes_strings{length(reconned_volumes_strings)+1}=vol_string;
        end
    end
    
    num_unreconned = length(unreconned_volumes); % For reporting purposes
    num_reconned = length(reconned_volumes); % For reporting purposes
    %% Let the user know the status of the recon.
    s_string = 's';
    if (n_volumes == 1)
        s_string = '';
    end
    if (num_unreconned == 0)
        log_msg =sprintf('All %i volume%s have been fully reconstructed.\n',n_volumes,s_string);
        yet_another_logger(log_msg,log_mode,log_file);
        return % Will this bust us out of this 'if' statement, or the whole function?
    else
        log_msg =sprintf('%i of %i volume%s have not been fully reconstructed yet; proceeding to look for prerequisite input data.\n',num_unreconned,n_volumes,s_string);
        yet_another_logger(log_msg,log_mode,log_file);
    end
    %% Do work if needed, first by finding input fid(s).
    if (num_unreconned > 0)
        running_jobs = '';
        
        m = matfile(recon_file,'Writable',true);
        m.study_workdir = workdir;
        m.scale_file = [workdir '/' runno '_4D_scaling_factor.float'];
        m.fid_tag_file = [workdir '/.' runno '.fid_tag'];
        m.dim_x = dim_x;
        m.dim_y = dim_y;
        m.dim_z = dim_z;
        m.runno = runno;
        
        if ~exist('scanner_host_name','var')
            aa=load_scanner_dependency(scanner);
            scanner_host_name=aa.scanner_host_name;  
        end
        scanner_name = scanner;
        m.scanner_name=scanner_name;
        scanner=scanner_host_name;
        
        m.scanner = scanner; 
        m.study = study;
        m.agilent_series = agilent_series;
        m.procpar_file = procpar_file;
        m.n_volumes = n_volumes;
        m.nechoes = nechoes;
        m.log_file = log_file;
        m.bbytes=bbytes;
        m.ntraces=ntraces;
        m.npoints=npoints;
        m.bitdepth=bitdepth;

        m.sampling_fraction = sampling_fraction;
        m.mask = mask;
        m.CSpdf = CSpdf;
        m.phmask = phmask;
        m.recon_dims = recon_dims;
        
        m.original_dims = original_dims;
        m.original_mask = original_mask;
        m.original_pdf = original_pdf;
        
        m.options = options; % The following shall soon be cannibalized by options!
        
        m.target_machine = target_machine;
        m.chunk_size = chunk_size;
        
        
        % Temp hardcoding before proper option handling
        TVWeight = 0.0012;
        m.TVWeight = TVWeight;
        
        xfmWeight =0.006;
        
        
        m.xfmWeight = xfmWeight;

        if ~exist('Itnlim','var')
            Itnlim = 98; %%98 is default
        end
        
        m.Itnlim = Itnlim;
        
        OuterIt = 1;
        m.OuterIt = OuterIt;
        
        m.fermi_filter=fermi_filter;
        
        if exist('email_addresses','var')
            m.email_addresses = email_addresses;
        end    
        
        % For single-block fids, wait for completion and then slice as
        % necessary.
        if (nechoes >  1) %nblocks == 1 --> we can let single echo GRE fall through the same path as DTI
            if ~exist('local_or_streaming_or_static','var')
                [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
            end
            
            if (local_or_streaming_or_static == 2)
                log_msg =sprintf('WARNING: Unable to stream recon for this type of scan (single-block fid); will wait for scan to complete.\n');
                yet_another_logger(log_msg,log_mode,log_file);   
                input_fid = ['/home/mrraw/' study '/' agilent_series '.fid/fid'];   
            end
            
            if ~exist(local_fid,'file') % If local_fid exists, then it will also be input_fid.
                missing_fids = 0;                

                for vs = 1:length(unreconned_volumes_strings)
                    runno_m_string=[runno '_m' unreconned_volumes_strings{vs}]; 
                    subvolume_workspace_file = [workdir  runno_m_string '/' runno_m_string '_workspace.mat'];
                    	
                    try
                        dummy_mf = matfile(subvolume_workspace_file,'Writable',false);
                        tmp_param = dummy_mf.param;
                    catch
                        c_fid = [workdir runno '_m' unreconned_volumes_strings{vs} '.fid'];
                        if ~exist(c_fid,'file')
                           missing_fids = missing_fids+1; 
                        end
                    end
                end
                
                if missing_fids
                    block_number=1;
                    remote_user='omega';
                    ready=check_subvolume_ready_in_fid_quiet(input_fid,block_number,bbytes,scanner,remote_user);
                end
                    
                if ready
                    if ~exist('datapath','var')
                        datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
                    end              
                    
                    puller_glusterspaceCS_2(runno,datapath,scanner,workdir,3);
                    
                    if ~exist(local_fid,'file') % It is assumed that the target of puller is the local_fid
                        error_flag = 1;
                        log_msg =sprintf('Unsuccessfully attempt to pull file from scanner %s: %s. Dying now.\n',scanner,[datapath '/fid']);
                        yet_another_logger(log_msg,log_mode,log_file,error_flag);
                        quit force
                    end
                        
                else % Setup watcher/gatekeeper
                    
                    gk_slurm_options=struct;
                    gk_slurm_options.v=''; % verbose
                    gk_slurm_options.s=''; % shared; gatekeeper definitely needs to share resources.
                    gk_slurm_options.mem=512; % memory requested; gatekeeper only needs a miniscule amount.
                    gk_slurm_options.p=gatekeeper_queue;
                    gk_slurm_options.job_name = [runno '_gatekeeper'];
                    %gk_slurm_options.reservation = active_reservation;
                    
                    study_gatekeeper_batch = [workdir '/sbatch/' runno '_gatekeeper.bash'];
                    gatekeeper_cmd = sprintf('%s %s %s %s %s %s %i %i', gatekeeper_exec, matlab_path,local_fid,input_fid,scanner,log_file,1,bbytes);
                    batch_file = create_slurm_batch_files(study_gatekeeper_batch,gatekeeper_cmd,gk_slurm_options)
                    running_jobs = dispatch_slurm_jobs( batch_file,slurm_options);
                    
                end 
                
            end
            
            % Run splitter, using job_dependencies if necessary
            fs_slurm_options=struct;
            fs_slurm_options.v=''; % verbose
            fs_slurm_options.s=''; % shared; volume setup should to share resources.
            fs_slurm_options.mem=50000; % memory requested; fs needs a significant amount; could do this smarter, though.
            fs_slurm_options.p=cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
            fs_slurm_options.job_name = [runno '_fid_splitter_recon'];
            fs_slurm_options.reservation = active_reservation;
            
            or_dependency = '';
            if ~isempty(running_jobs)
                or_dependency='afterok-or';
            end
                      
            fid_splitter_batch = [workdir 'sbatch/' runno '_fid_splitter_CS_recon.bash'];
            fs_cmd = sprintf('%s %s %s %s', fid_splitter_exec,matlab_path, local_fid,recon_file);
            batch_file = create_slurm_batch_files(fid_splitter_batch,fs_cmd,fs_slurm_options);
            fid_splitter_running_jobs = dispatch_slurm_jobs(batch_file,'',running_jobs,or_dependency);
            
        end % End of single volume and MGRE preprocessing.
        
        
        % Setup individual volumes to be reconned, with the assumption that
        % its own .fid file exists
        
        for vs = 1:length(unreconned_volumes_strings)    
            volume_runno = [runno '_m' unreconned_volumes_strings{vs}];
            volume_number = unreconned_volumes(vs);
            volume_dir = [ workdir volume_runno '/'];
            if ~exist(volume_dir,'dir')
                system(['mkdir -m 775 ' volume_dir]);
                vol_sbatch_dir = [volume_dir 'sbatch'];
                %if ~exist(vol_sbatch_dir,'dir')
                system(['mkdir -m 775 ' vol_sbatch_dir]);
                %end
                %%% mkdir commands pulled into here from check status,
                images_dir = fullfile(volume_dir,[volume_runno 'images']);
                %if ~exist(images_dir,'dir')
                system(['mkdir -m 775 ' images_dir]);
                %end
                work_subfolder = fullfile(volume_dir,'work');
                %if ~exist(work_subfolder,'dir')
                system(['mkdir -m 775 ' work_subfolder]);
                %end
            end
            
            vm_slurm_options=struct;
            vm_slurm_options.v=''; % verbose
            vm_slurm_options.s=''; % shared; volume manager needs to share resources.
            vm_slurm_options.mem=512; % memory requested; vm only needs a miniscule amount.
            vm_slurm_options.p=gatekeeper_queue;% cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
            vm_slurm_options.job_name = [volume_runno '_volume_manager'];
            %vm_slurm_options.reservation = active_reservation;
            
            volume_manager_batch = [volume_dir 'sbatch/' volume_runno '_volume_manager.bash'];
            vm_cmd = sprintf('%s %s %s %s %i %s', volume_manager_exec, matlab_path, recon_file,volume_runno, volume_number,workdir);
            %%% James's happy delay patch
            delay_unit=5;
            vm_cmd=sprintf('sleep %i\n%s',(vs-1)*delay_unit,vm_cmd);
            
            batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
            
            or_dependency = '';
            if ~isempty(running_jobs)
               or_dependency='afterok-or'; 
            end
            c_running_jobs = dispatch_slurm_jobs(batch_file,'',running_jobs,or_dependency);
            
            log_msg =sprintf('Initializing Volume Manager for volume %s (SLURM jobid(s): %s).\n',volume_runno,c_running_jobs);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    end
    %% Pull fid and procpar, load reconstruction parameter data
    % CSreconfile = agilent2glusterspaceCS_wn(scanner,runno,study,series,recon_path);
%    reconfile = agilent2glusterspaceCS(scanner,runno,study,series,recon_path);
    
%    load(reconfile)
end % This 'end' belongs to the study_flag check
end

function [recon_file] = specid_to_recon_file(scanner,runno,recon_file)

databuffer.engine_constants = load_engine_dependency();
databuffer.scanner_constants = load_scanner_dependency(scanner);
databuffer.headfile.U_runno = runno;
databuffer.headfile.U_scanner = scanner;

databuffer.input_headfile = struct; % Load procpar here.

databuffer.headfile = combine_struct(databuffer.headfile,databuffer.engine_constants);
databuffer.headfile = combine_struct(databuffer.headfile,databuffer.scanner_constants);

optstruct.testmode = false;
optstruct.debug_mode = 0;
optstruct.warning_pause = 0;

optstruct.param_file =[runno '.param']; 
gui_info_collect(databuffer,optstruct);

 m = matfile(recon_file,'Writable',true);
 m.databuffer = databuffer;
 m.optstruct = optstruct;
end

function [dim_y, dim_z, n_sampled_lines,sampling_fraction,mask,CSpdf,phmask,recon_dims,original_mask,original_pdf,original_dims]= process_CS_mask(procpar_or_CStable,dim_x)
    [mask, dim_y, dim_z, pa, pb ] = extract_info_from_CStable(procpar_or_CStable);
    
    n_sampled_lines=sum(mask(:));
    sampling_fraction = n_sampled_lines/length(mask(:));

    original_dims = [dim_x dim_y dim_z];
    
    % Generate sampling PDF (this is not the sampling mask)

    [CSpdf,~] = genPDF_wn_v2(original_dims(2:3),pa,sampling_fraction,pb,false);

    original_mask = mask;
    original_pdf = CSpdf;

    % pad if non-square or non-power of 2

    dyadic_idx = 2.^(1:14); %dyadic_idx = 2.^[1:12]; %%%% 12->14
    pidx = find(max(original_dims(2:3))<=dyadic_idx,1);
    p = 2^pidx;

    if (p>max(original_dims(2:3)))
        mask = padarray(original_mask,[p-original_dims(2) p-original_dims(3)]/2,0,'both');
        CSpdf = padarray(CSpdf,[p-original_dims(2) p-original_dims(3)]/2,1,'both'); %pad with 1's since we don't want to divide by zero later
    end
    recon_dims = [original_dims(1) size(mask)];%size(data);

    phmask = zpad(hamming(32)*hamming(32)',recon_dims(2),recon_dims(3)); %mask to grab center frequency
    phmask = phmask/max(phmask(:));			 %for low-order phase estimation and correction

end