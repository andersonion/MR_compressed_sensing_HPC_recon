function streaming_CS_recon_main_exec(scanner,runno,study,agilent_series, varargin )
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
   
if ~isdeployed
    %% Get all necessary code for reconstruction
    run(fullfile(fileparts(mfilename('fullfile')),'compile__pathset.m'))
else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end
%% clean up what user said to us.
% since we have some optional positional args, and legacy behavior,
% lets try to sort those out kindly for users.
if ~ischar(agilent_series)
    agilent_series = num2str(agilent_series);
    if length(agilent_series) < 2
        agilent_series = ['0' agilent_series];
    end
    agilent_series = ['ser' agilent_series];
end
% varargin 1 and 2 might be positional arguments.
% check them for an equals sign, if its misssing check for loose
% number(Itnlim), or string(CS_table).
% Side effect of doing it this way, we'll now accept them in either order. 
for pc=1:min(2,length(varargin))
    if isempty(regexpi(varargin{pc},'=')) % there is no equals sign
        if ~isempty(regexpi(varargin{pc},'^[0-9]+$'))
            if numel(strfind(strjoin(varargin),'Itnlim'))==0
                varargin{pc}=sprintf('Itnlim=%s',varargin{pc});
            else
                error('Found loose number(%s), but also specified Itnlim later, not sure what to do with it!',varargin{pc});
                % pause(3);
            end
        elseif ~isempty(regexpi(varargin{pc},'^CS[0-9]+_[0-9]+x_.*$'))
            % example CS_table 'CS256_8x_pa18_pb54' In theory, this regular expression allows
            % out to infinity size and compression
            if numel(strfind(strjoin(varargin),'CS_table'))==0
                varargin{pc}=sprintf('CS_table=%s',varargin{pc});
            else
                error('Found CS_table (%s), but also specified later, not sure what to do with it!',varargin{pc});
                % pause(3);
            end
        end
    else
        break; % as soon as we find = signs, we're in the auto opt portion.
    end
end
%% run the option digester
types.standard_options={...
    'target_machine',       'which regular engine should we send data to for archival.' 
    'CS_table',             ' the CS table on the scanner to use. Must be specified in streaming mode.' 
    'first_volume',         ' start reconstructing at volume N, The first volume will also be processed!'
    'last_volume',          ' stop reconstructing at volume N.'
    'roll_data',            ' pre-roll the data before reconstruction'
    'skip_fermi_filter',    'do not do fermi_filtering of kspace before fft' 
    'iteration_strategy',   ' the iteration/initalizaiton scheme to use, 10x5 by default. '
    'Itnlim',               'number of iterations, would like to rename ot max_iterations. Probably have to chase this down in the code.'
    're_init_count',        ' how many times will we be re-initalizing default 4(maybe this is bad because we do one more block of iterations than this implies)'
    'TVWeight',             ''
    'xfmWeight',            ''
    'hamming_window',       ' used in the creation of phmask'
    'process_headfiles_only',    ' skip image reconstruction and only process headfile(s)'
    };
types.beta_options={...
    'CS_reservation',       ' specify reservation to run on' 
    'fid_archive',          ' sends CS_fid to target_machine so we can run fid_archive on it there'
    };
types.planned_options={...
    'wavelet_dims',         ''
    'wavelet_type',         ''
    'chunk_size',           ' How many cs slices per slice job. Controls job run time. Ideally we shoot for 5-15 min job time.'
    'fermi_w1',             ''
    'fermi_w2',             ''
    'convergence_threshold',''
    'keep_work',           ''
    'email_addresses',      ''
    'verbosity',             ''
    'live_run',             ' run the code live in matlab, igored when deployed.'
    'CS_preview_data',      ' save a pre recon orthocenter of kspace and imgspace'
    };
options=mat_pipe_option_handler(varargin,types);
% A reminder, mat_pipe_option handler exists to do two things. 
% 1. provide half decent help for your function. 
% 2. clean up options to a known state to make option use easier, 
%    a. all options are defined, and false by default. This lets you do if
%    option.optname to know if its defined and you have to do something
%    with it. This can lead to weird behavior with default true things. 
%    b. numeric options are set to best type, and roughly evaluated, 
%       eg, in the structure arrays are arrays, vectors will be vectors.
%
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

%% Current defaults--option handling will be upgraded shortly
if isdeployed && options.live_run
    warning('cant live run when deployed :p');
    options.live_run=0;
elseif ~isdeployed && ~options.live_run
    warning('Running in matlab, but live run is off, we''ll be scheduling slurm jobs. Are you sure thats what you wanted?');
    pause(3);
end
% james normally attaches this to the "debug_val" option, 
% with increasing values of debugging generating more and more outtput.
options.verbose=1;
log_mode = 2; % Log only to log file.
if options.verbose
    log_mode = 1; % Log to file and standard out/error.
end
if ~options.target_machine
    options.target_machine = 'delos';
end
% since options are defacto off, this should set inverse.
options.fermi_filter=~options.skip_fermi_filter; 
if ~options.chunk_size
    % 25 November 2016, temporarily (?) changed to 6
    % 2018 07 05 set to 30 like our wrapping shell script to reduce cluster
    % over load.
    options.chunk_size=30;
end
if islogical(options.TVWeight)
    options.TVWeight = 0.0012;
end
if islogical(options.xfmWeight)
    %%{
    % this is the value nian has been using, and not the one gary has been
    % using. 
    options.xfmWeight =0.006;
    %}
    %{
    % this is the value gary has been using, however, not the one nian has
    % been using.
    options.xfmWeight =0.002; 
    %}
end
if ~options.hamming_window
    options.hamming_window=32;
end
if options.CS_preview_data
   if islogical(options.CS_preview_data)
       options.CS_preview_data='slice';
   elseif isempty(regexpi(options.CS_preview_data,'slice|volume'));
       error('bad CS_preview_data value, choose slice or volume');
   end
end
%% iteration determination with glorious complication !
% uses "temporary" option re_init_count which is 
% the number of iteration blocks -1 (becuase Re_init :) ) 
% both iteration_strategy, and re_init_count are done after this, with no
% further direct use.
%
% To make the block size uneven we should make an array of iteration
% blocks, much like we do with TVWeight and xfmWeight.
%
if ~options.iteration_strategy
    % previous default, would like to changing it to bj's found "good" value of
    % 10 with 4 re-inits(50 total iterations) but dont want to disrupt
    % current studies.
    if ~options.Itnlim
        options.Itnlim=100;
        % options.Itnlim=50;
    end
    if ~options.re_init_count 
        % this one is kinda silly becuase we default to 0 anyway. this is
        % just here to hold the idea open for when we set default to 4.
        options.re_init_count=0;
        %options.re_init_count=4;
    end
    options.iteration_strategy=sprintf('%ix%i',options.Itnlim/(options.re_init_count+1),options.re_init_count+1);
else
    if options.keep_work
        error('keep_work and iteration_strategy are not tested together');
    end
    options.iteration_strategy=strsplit(options.iteration_strategy,'x');
    ic=str2double(options.iteration_strategy(1));
    options.re_init_count=str2double(options.iteration_strategy(2))-1;
    options.Itnlim=ic*(options.re_init_count+1);
    options.iteration_strategy=strjoin(options.iteration_strategy,'x');
end
if numel(options.xfmWeight) == 1
    options.xfmWeight= ones(1,options.re_init_count+1)*options.xfmWeight;
end
if numel(options.TVWeight) == 1
    options.TVWeight= ones(1,options.re_init_count+1)*options.TVWeight;
end
if numel(options.xfmWeight) ~=  numel(options.TVWeight) ...
    || numel(options.xfmWeight) ~= options.re_init_count+1
    error('mis-match for our re_initalizations and required params, TVWeight and xfmWeight');
end
%% user configurable scanner user.
% only partially implemented :D 
if ~options.scanner_user
    scanner_user='omega';
else
    scanner_user=options.scanner_user;
end
%% Reservation support
active_reservation=get_reservation(options.CS_reservation);
options.CS_reservation=active_reservation;
%% Give options feedback to user, with pause so they can cancel
fprintf('Ready to start! Here are your selected options\n');
fprintf('Ctrl+C now to stop and try again\n');
fields=fieldnames(options);
for fn=1:numel(fields)
    if iscell(options.(fields{fn}))
        ot='cell array!';
    elseif ~ischar(options.(fields{fn}))
        ot=sprintf('%g ',options.(fields{fn}));
    else
        ot=options.(fields{fn});
    end
    if islogical(options.(fields{fn})) ...
            && ~options.(fields{fn})
        % skip any "off" fields.... may be bad idea, we'll see.
        continue;
    end
    fprintf('\t%s = \t%s\n',fields{fn},ot);
end; clear fields fn;
pause(3);
%% Determine where the matlab executables live
%  May change this to look to environment variables, or a seperate
%  head/textfile, which will give us dynamic flexibility if our goal is
%  have end-to-end deployability.
% the CS_CODE_DEV setting cant be entirely in options as main is one of the
% "versioned" pieces of code.
matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
% Gatekeeper support
gatekeeper_path = getenv('CS_GATEKEEPER_EXEC');
% set an env var to get latest dev code, or will defacto run stable.
CS_CODE_DEV=getenv('CS_CODE_DEV');
if isempty(CS_CODE_DEV)
    CS_CODE_DEV='stable';
end
if isempty(gatekeeper_path)
    gatekeeper_path = [ '/cm/shared/workstation_code_dev/matlab_execs/gatekeeper_executable/' CS_CODE_DEV '/run_gatekeeper_exec.sh'] ;
    setenv('CS_GATEKEEPER_EXEC',gatekeeper_path);
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
fid_splitter_path = getenv('CS_FID_SPLITTER_EXEC');
if isempty(fid_splitter_path)
    fid_splitter_path = [ '/cm/shared/workstation_code_dev/matlab_execs/fid_splitter_executable/' CS_CODE_DEV '/run_fid_splitter_exec.sh' ];
    setenv('CS_FID_SPLITTER_EXEC',fid_splitter_path);
end
volume_manager_path = getenv('CS_VOLUME_MANAGER_EXEC');
if isempty(volume_manager_path)
    volume_manager_path = [ '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/' CS_CODE_DEV '/run_volume_manager_exec.sh'];
    setenv('CS_VOLUME_MANAGER_EXEC',volume_manager_path);
end
%% Get workdir
scratch_drive = getenv('BIGGUS_DISKUS');
workdir = fullfile(scratch_drive,[runno '.work']);
if ~exist(workdir,'dir');
    mkdir_cmd = sprintf('mkdir -m 775 %s',workdir);
    system(mkdir_cmd);
end
% Initialize a log file if it doesn't exist yet.
log_file = fullfile(workdir,[ runno '.recon_log']);
if ~exist(log_file,'file')
    system(['touch ' log_file]);
end
local_fid=fullfile(workdir,[runno '.fid']);
study_flag = [workdir '/.' runno '.recon_completed'];
%% Write initialization info to log file.
ts=fix(clock);
t=datetime(ts(1:3));
month_string = month(t,'name');
start_date=sprintf('%02i %s %04i',ts(3),month_string{1},ts(1));
start_time=sprintf('%02i:%02i',ts(4:5));
user = getenv('USER');
log_msg =sprintf('\n');
log_msg=sprintf('%s----------\n',log_msg);
log_msg=sprintf('%sCompressed sensing reconstruction initialized on: %s at %s.\n',log_msg,start_date, start_time);
log_msg=sprintf('%s----------\n',log_msg);
log_msg=sprintf('%sScanner study: %s\n',log_msg, study);
log_msg=sprintf('%sScanner series: %s\n',log_msg, agilent_series);
log_msg=sprintf('%sUser: %s\n',log_msg,user);
log_msg=sprintf('%sExec Set: %s\n',log_msg,CS_CODE_DEV);
yet_another_logger(log_msg,log_mode,log_file);
% Check to see if a flag_file for complete recon exists
if ~exist(study_flag,'file')
    %% First things first: get specid from user!
    % Create or get one ready.
    recon_file = fullfile(workdir,[runno 'recon.mat']);
    if ~exist(recon_file,'file')
        m = specid_to_recon_file(scanner,runno,recon_file);
    else
        m = matfile(recon_file,'Writable',true);
    end
    %% Test ssh connectivity using our perl program which has robust ssh handling.
    puller_test=sprintf('puller_simple -oer -f file %s ../../../../home/vnmr1/vnmrsys/tablib/%s %s/%s',...
        scanner,options.CS_table,workdir,options.CS_table);
    [s,sout]=system(puller_test);
    if s~=0
        error(sout);
    end
    
    %% Second First things first: determine number of volumes to be reconned
    local_hdr = fullfile(workdir,[runno '_hdr.fid']);
    [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
    if ~exist(local_hdr,'file');
        if (local_or_streaming_or_static == 1)
            get_hdr_from_fid(input_fid,local_hdr);
        else
            if (local_or_streaming_or_static == 2)
                log_msg =sprintf('WARNING: Inputs not found locally or on scanner; running in streaming mode.\n');
                yet_another_logger(log_msg,log_mode,log_file);
            end
            get_hdr_from_fid(input_fid,local_hdr,scanner);
        end
    end
    
    varlist='npoints,nblocks,ntraces,bitdepth,bbytes,dim_x';
    missing=matfile_missing_vars(recon_file,varlist);
    if missing>0
        [m.npoints,m.nblocks,m.ntraces,m.bitdepth,m.bbytes,~,~] = load_fid_hdr_details(local_hdr);
        m.dim_x = round(m.npoints/2);
    end
    procpar_file = fullfile(workdir,[runno '.procpar']);
    procpar_or_CStable= procpar_file;
    if ~exist(procpar_file,'file')
        if (local_or_streaming_or_static == 2) 
            %% streaming mode
            tables_in_workdir=dir([workdir '/CS*_*x*_*']);
            if (isempty(tables_in_workdir))
                if (~options.CS_table)
                    %options.CS_table = input('Please enter the name of the CS table used for this scan.','s');
                    list_cs_tables_cmd = [ 'ssh ' scanner_user '@' scanner ' ''cd /home/vnmr1/vnmrsys/tablib/; ls CS*_*x_*'''];
                    [~,available_tables]=ssh_call(list_cs_tables_cmd);
                    log_msg = sprintf('Please rerun this code and specify the CS_table to run in streaming mode\n');
                    log_msg=sprintf('%s\t(otherwise you will need to wait until the entire scan completes).\n',log_msg);
                    log_msg=sprintf('%sAvailable tables:\n%s\n',log_msg,available_tables);
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
            procpar_or_CStable=fullfile(workdir,options.CS_table);
            yet_another_logger(log_msg,log_mode,log_file);
        else
            %% local or static mode
            %datapath='/home/mrraw/' study '/' agilent_series '.fid'];
            datapath=fullfile('/home/mrraw',study,[agilent_series '.fid']);
            mode =2; % Only pull procpar file
            puller_glusterspaceCS_2(runno,datapath,scanner,workdir,mode);
        end
    end
    %% Might as well process skiptable/mask while we're here
    % we can check if we've done this before using the whos command
    varlist=['dim_y,dim_z,n_sampled_lines,sampling_fraction,mask,'...
        'CSpdf,phmask,recon_dims,original_mask,original_pdf,original_dims,nechoes,n_volumes'];
    missing=matfile_missing_vars(recon_file,varlist);
    if missing>0
        [m.dim_y,m.dim_z,m.n_sampled_lines,m.sampling_fraction,m.mask,m.CSpdf,m.phmask,m.recon_dims,...
            m.original_mask,m.original_pdf,m.original_dims] = process_CS_mask(procpar_or_CStable,m.dim_x,options);
        m.nechoes = 1;
        if (m.nblocks == 1)
            m.nechoes = round(m.ntraces/m.n_sampled_lines); % Shouldn't need to round...just being safe.
            m.n_volumes = m.nechoes;
        else
            m.n_volumes = m.nblocks;
        end
        
        % Please enhance later to not be so clumsy (include these variables
        % in the missing variable list elsewhere in this function.

        bh=struct;
        original_dims=m.original_dims;
        bh.dim_X=original_dims(1);
        bh.dim_Y=original_dims(2);
        bh.dim_Z=original_dims(3);
        bh.A_dti_vols=m.n_volumes;
        bh.A_channels = 1;
        bh.A_echoes = m.nechoes;
        %bh.U_runno = volume_runno;
        temp=m.databuffer;
        gui_info = read_headfile(fullfile(temp.engine_constants.engine_recongui_paramfile_directory,[runno '.param']));
        faux_struct1 = combine_struct(bh,gui_info,'U_');
        temp.headfile = combine_struct(temp.headfile,faux_struct1);
        m.databuffer=temp;
    end; 
    %% Check all n_volumes for incomplete reconstruction
    %WARNING: this code relies on each entry in recon status being
    %filled in. This should be fine, but take care when refactoring.
    recon_status=zeros(1,m.n_volumes);
    vol_strings=cell(1,m.n_volumes);
    for vn = 1:m.n_volumes
        vol_string =sprintf(['%0' num2str(numel(num2str(m.n_volumes-1))) 'i' ],vn-1);
        volume_runno = sprintf('%s_m%s',runno,vol_string);
        volume_flag=sprintf('%s/%s/%simages/.%s_send_archive_tag_to_%s_SUCCESSFUL', workdir,volume_runno,volume_runno,volume_runno,options.target_machine);
        vol_strings{vn}=vol_string;
        if exist(volume_flag,'file')
            recon_status(vn)=1;
        end
    end
    %reconned_volumes=find(recon_status);
    unreconned_volumes=find(~recon_status);
    %reconned_volumes_strings=vol_strings(find(recon_status));
    unreconned_volumes_strings=vol_strings(find(~recon_status));
    num_unreconned = length(unreconned_volumes); % For reporting purposes
    % num_reconned = length(reconned_volumes); % For reporting purposes
    %% Let the user know the status of thesave recon.
    s_string = 's';
    if (m.n_volumes == 1)
        s_string = '';
    end
    log_msg =sprintf('%i of %i volume%s have fully reconstructed.\n',m.n_volumes-num_unreconned,m.n_volumes,s_string);
    yet_another_logger(log_msg,log_mode,log_file);
    %% Do work if needed, first by finding input fid(s).
    if (num_unreconned > 0)
        m.study_workdir = workdir;
        m.scale_file = fullfile(workdir,[ runno '_4D_scaling_factor.float']);
        m.fid_tag_file = fullfile(workdir, [ '.' runno '.fid_tag']);
        %% tangled web of support scanner name ~= host name.
        if ~exist('scanner_host_name','var')
            % What madness is this! Reloading data, Never!...
            %aa=load_scanner_dependency(scanner);
            try 
                aa=m.scanner_constants;
            catch
            end
            if ~exist('aa','var')
                try 
                    db=m.databuffer;
                    aa=db.scanner_constants;
                catch
                end
            end
            scanner_host_name=aa.scanner_host_name;
            if ~exist('scanner_user','var')
                scanner_user=aa.scanner_user;
            end
        end
        scanner_name = scanner;
        m.scanner_name=scanner_name;
        scanner=scanner_host_name;
        m.scanner = scanner;
        %% continue stuffing vars to matfile.
        m.runno = runno;
        m.study = study;
        m.agilent_series = agilent_series;
        m.procpar_file = procpar_file;
        m.log_file = log_file;
        m.options = options; % The following shall soon be cannibalized by options!
        transcribed_opts={'target_machine','chunk_size','TVWeight','xfmWeight','Itnlim','fermi_filter','verbosity'};
        for on=1:numel(transcribed_opts)
            m.(transcribed_opts{on})=options.(transcribed_opts{on});
        end
        if ~islogical(options.email_addresses)
            m.email_addresses = options.email_addresses;
        end
        % For single-block fids, wait for completion and then slice as
        % necessary.
        running_jobs = '';
        if (m.nechoes >  1) %nblocks == 1 --> we can let single echo GRE fall through the same path as DTI
            if ~exist('local_or_streaming_or_static','var')
                warning('Weird code here, should never run, debug later - james');
                [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
            end
            if (local_or_streaming_or_static == 2) 
                %% if we're streaming a MGRE or single block
                log_msg =sprintf('WARNING: Unable to stream recon for this type of scan (single-block fid); will wait for scan to complete.\n');
                yet_another_logger(log_msg,log_mode,log_file);
                input_fid = ['/home/mrraw/' study '/' agilent_series '.fid/fid'];
            end
            if ~exist(local_fid,'file') % If local_fid exists, then it will also be input_fid.
                missing_fids = 0;
                for vs = 1:length(unreconned_volumes_strings)
                    volumn_runno = [runno '_m' unreconned_volumes_strings{vs}];
                    subvolume_workspace_file = [workdir '/' volumn_runno '/' volumn_runno '_workspace.mat'];
                    try
                        dummy_mf = matfile(subvolume_workspace_file,'Writable',false);
                        tmp_param = dummy_mf.param;
                    catch
                        c_fid = [workdir '/' volumn_runno '.fid'];
                        if ~exist(c_fid,'file')
                            missing_fids = missing_fids+1;
                        end
                    end
                end
                if missing_fids
                    block_number=1;
                    ready=check_subvolume_ready_in_fid_quiet(input_fid,block_number,m.bbytes,scanner,scanner_user);
                end
                if ready
                    if ~exist('datapath','var')
                        datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
                    end
                    puller_glusterspaceCS_2(runno,datapath,scanner,workdir,3);
                    if ~exist(local_fid,'file') % It is assumed that the target of puller is the local_fid
                        error_flag = 1;
                        log_msg =sprintf('Unsuccessfully attempt to pull file from scanner %s: %s. Dying now.\n',...
                            scanner,[datapath '/fid']);
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
                    % using a blank reservation to force no reservation for this job.
                    gk_slurm_options.reservation = '';
                    study_gatekeeper_batch = [workdir '/sbatch/' runno '_gatekeeper.bash'];
                    gatekeeper_cmd = sprintf('%s %s %s %s %s %s %i %i', ...
                        gatekeeper_path, matlab_path,local_fid,input_fid,scanner,log_file,1,m.bbytes);
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
            fid_splitter_batch = [workdir '/sbatch/' runno '_fid_splitter_CS_recon.bash'];
            fs_cmd = sprintf('%s %s %s %s', fid_splitter_path,matlab_path, local_fid,recon_file);
            batch_file = create_slurm_batch_files(fid_splitter_batch,fs_cmd,fs_slurm_options);
            fid_splitter_running_jobs = dispatch_slurm_jobs(batch_file,'',running_jobs,or_dependency);
        end % End of single volume and MGRE preprocessing.
        % Setup individual volumes to be reconned, with the assumption that
        % its own .fid file exists
        for vs = 1:length(unreconned_volumes_strings)
            %%% first_volume, last_volume handling, by just skiping loop.
            vn=str2num(unreconned_volumes_strings{vs})+1;
            if isnumeric(options.first_volume) && options.first_volume
                    if vn~=1 && vn<options.first_volume
                        continue;
                    end
            end
            if isnumeric(options.last_volume) && options.last_volume
                if vn~=1 && vn>options.last_volume
                    continue;
                end
            end
            volume_runno = [runno '_m' unreconned_volumes_strings{vs}];
            volume_number = unreconned_volumes(vs);
            volume_dir = fullfile(workdir,volume_runno);
            vol_sbatch_dir = fullfile(volume_dir, 'sbatch');
            work_subfolder = fullfile(volume_dir, 'work');
            images_dir     = fullfile(volume_dir,[volume_runno 'images']);
            if ~exist(images_dir,'dir')
                %%% mkdir commands pulled into here from check status,
                fprintf('Making voldir,sbatch,work,images,directories\n');    
                mkdir_s(1)=system(['mkdir -m 775 ' volume_dir]);
                mkdir_s(2)=system(['mkdir -m 775 ' vol_sbatch_dir]);
                mkdir_s(3)=system(['mkdir -m 775 ' work_subfolder]);
                mkdir_s(4)=system(['mkdir -m 775 ' images_dir]);
                if(sum(mkdir_s)>0)
                    log_msg=sprintf('error with mkdir for %s\n will need to remove dir %s to run cleanly. ',volume_runno,volume_dir);
                    yet_another_logger(log_msg,log_mode,log_file,1);
                    quit force
                end
            end
            vm_slurm_options=struct;
            vm_slurm_options.v=''; % verbose
            vm_slurm_options.s=''; % shared; volume manager needs to share resources.
            
            % memory requested; volume manager only needs a miniscule amount.
            %--In theory only! For yz-array sizes > 2048^2, loading the
            % data of phmask, CSmask, etc can push the memory of 512 MB
            vm_slurm_options.mem=2048;
            vm_slurm_options.p=gatekeeper_queue;% cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
            vm_slurm_options.job_name = [volume_runno '_volume_manager'];
            %vm_slurm_options.reservation = active_reservation;
            % using a blank reservation to force no reservation for this job.
            vm_slurm_options.reservation = ''; 
            volume_manager_batch = fullfile(volume_dir,'sbatch',[ volume_runno '_volume_manager.bash']);
            vm_args=sprintf('%s %s %i %s',recon_file,volume_runno, volume_number,workdir);
            vm_cmd = sprintf('%s %s %s ', volume_manager_path, ...
                matlab_path, vm_args);
            %%% James's happy delay patch
            if ~options.process_headfiles_only
                delay_unit=5;
                vm_cmd=sprintf('sleep %i\n%s',(vs-1)*delay_unit,vm_cmd);
            end
            if ~options.live_run
                batch_file = create_slurm_batch_files(volume_manager_batch,vm_cmd,vm_slurm_options);
                or_dependency = '';
                if ~isempty(running_jobs)
                    or_dependency='afterok-or';
                end
                c_running_jobs = dispatch_slurm_jobs(batch_file,'',running_jobs,or_dependency);
                log_msg =sprintf('Initializing Volume Manager for volume %s (SLURM jobid(s): %s).\n',volume_runno,c_running_jobs);
                yet_another_logger(log_msg,log_mode,log_file);
            elseif options.live_run
                eval(sprintf('volume_manager_exec %s',vm_args));
            end
        end
    end
    %% Pull fid and procpar, load reconstruction parameter data
    % CSreconfile = agilent2glusterspaceCS_wn(scanner,runno,study,series,recon_path);
    %    reconfile = agilent2glusterspaceCS(scanner,runno,study,series,recon_path);
    %    load(reconfile)
end % This 'end' belongs to the study_flag check
if options.fid_archive && local_or_streaming_or_static==3
    % puller overwrite option
    poc='';
    % fid_archive overwrite option
    foc='';
    if options.overwrite
        poc='-eor';
        foc='-o';
    end
    pull_cmd=sprintf('puller_simple %s %s %s/%s* %s.work;fid_archive %s %s %s', ...
        poc,scanner,study,agilent_series,runno,foc,user,runno);
    ssh_and_run=sprintf('ssh %s@%s "%s"',getenv('USER'),options.target_machine,pull_cmd);
    log_msg=sprintf('Preparing fid_archive.\n\tSending data to target_machine can take a while.\n');
    log_msg=sprintf('%susing command:\n\t%s\n',log_msg,ssh_and_run);
    yet_another_logger(log_msg,log_mode,log_file);
    [~,out]=ssh_call(ssh_and_run);
    disp(out);
elseif options.fid_archive
    error('Fid_archive option incomplete for streaming, BJ may be able to fix this ');
    % NOTE to BJ; we need to schedule this behind a procpar watcher.
    % -james.
end
end

function m = specid_to_recon_file(scanner,runno,recon_file)
% holly horrors this function is bad form! 
% it combines several disjointed programming styles.
% the name is also terrible! 
m = matfile(recon_file,'Writable',true);
databuffer.engine_constants = load_engine_dependency();
databuffer.scanner_constants = load_scanner_dependency(scanner);

%if ~options.target_machine % we want this for automatic host name
%resolution, but this currently doesn't work!
%    databuffer.target_constants=load_engine_dependency(options.target_machine);
%end

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

m.databuffer = databuffer;
m.optstruct = optstruct;
end

function [dim_y, dim_z, n_sampled_lines, sampling_fraction, mask, ...
    CSpdf,phmask,recon_dims,original_mask,original_pdf,original_dims]= ...
    process_CS_mask(procpar_or_CStable,dim_x,options)
% function process_CS_mask 
fprintf('process_CS_mask ... this can take a minute.\n');
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

phmask = zpad(hamming(options.hamming_window)*hamming(options.hamming_window)',recon_dims(2),recon_dims(3)); %mask to grab center frequency
phmask = phmask/max(phmask(:));			 %for low-order phase estimation and correction
end
function missing=matfile_missing_vars(mat_file,varlist)
% function missing_count=matfile_missing_vars(mat_file,varlist)
% checks mat file for list of  vars,
% mat_file is the path to the .mat file, 
% varlist is the comma separated list of expected variables, WATCH OUT FOR
% SPACES.
    listOfVariables = who('-file',mat_file);
    lx=strsplit(varlist,',');
    missing=numel(lx);
    m_idx=zeros(size(lx));
    for v=1:numel(lx)
        if ismember(lx{v}, listOfVariables) % returns true
            missing = missing - 1;
        else
            m_idx(v)=1;
        end
    end
end