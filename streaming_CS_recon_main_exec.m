function streaming_recon_exec(scanner_name, runno, input_data, varargin )
%function streaming_recon_exec(scanner, runno, input, options_cell_array)
%
% scanner  - short name of scanner to get data input from
% runno    - run number for output. Multi_volume output will have a suffix
%            _m0-(N-1) for each volume
% input    - string or cell array of the data name on scanner
%            Can use * to guess any portion of the string except for
%            director boundaries.
%          - for agilent 20120101_01/ser01.fid
%            with wild card 20120101*/ser01.fid
%          - for mrsolutions data_file.mrd
%          -           or volume_index.txt
%
% option   - for a list and explaination use 'help'.
%
% scanner_data for nested structures would be data1/data2
% for our agilent scanners
%   study/series01.fid
%   study/series01
% for our mrsolutions scanners
% Copyright Duke University
% Authors: James J Cook, G Allan Johnson


% fileinput help for scanners we never made compression work on
%          - for aspect  '004534', by convention asepect runnumbers are
%          aspect id+6000
%          - for bruker   {'patientid','scanid'} or 'patientid/scanid'
%                (datanum is not supported yet?)
%          - list file support? List in radish_scale_bunch format? via
%          listmaker.


% old function line before joining the scanner data fields
%function streaming_CS_recon_main_exec(scanner_name,runno,scanner_patient,scanner_acquisition, varargin )
% matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
matlab_path=getenv('MATLAB_2021b_PATH');
recon_type = 'CS_v3.0';
typical_pa=1.8;
typical_pb=5.4;
if ~isdeployed
    %% Get all necessary code for reconstruction
    f_path=which('FWT2_PO');
    if isempty(f_path)
        run(fullfile(fileparts(mfilename('fullfile')),'compile_commands','compile__pathset.m'));
    end
else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end
if numel(varargin)==1 && iscell(varargin{1})
    varargin=varargin{1};
end
% shutting off legacy inputs for now
legacy_positional_args=0;
if legacy_positional_args
    % old arg setup, scanner_patient,scanner_acquisition, varargin
    % patch from new to to old
    db_inplace(mfilename,'untested');
    scanner_patient=varargin{1};
    scanner_series=varargin{2};
    varargin{1:2}=[];
    %% clean up what user said to us.
    % since we have some optional positional args, and legacy behavior,
    % lets try to sort those out kindly for users.
    if ~ischar(scanner_acquisition)
        scanner_acquisition = num2str(scanner_acquisition);
        if length(scanner_acquisition) < 2
            scanner_acquisition = ['0' scanner_acquisition];
        end
        scanner_acquisition = ['ser' scanner_acquisition];
    end
    % varargin 1 and 2 might be positional arguments.
    % check them for an equals sign, if its misssing check for loose
    % number(Itnlim), or string(CS_table).
    % Side effect of doing it this way, we'll now accept them in either order.
    for pc=1:min(2,length(varargin))
        if ~reg_match(varargin{pc},'=')
            if reg_match(varargin{pc},'^[0-9]+$')
                warning('Specifing iteration limit loosely is not recommended, use Itnlim=%i instead.',varargin{pc});
                if numel(strfind(strjoin(varargin),'Itnlim'))==0
                    varargin{pc}=sprintf('Itnlim=%s',varargin{pc});
                else
                    error('Found loose number(%s), but also specified Itnlim later, not sure what to do with it!',varargin{pc});
                    % pause(3);
                end
            elseif reg_match(varargin{pc},'^CS[0-9]+_[0-9]+x_.*$')
                warning('Specifing CS table loosly on commandline is not recommended, use CS_table=%s instead.',varargin{pc});
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
    end; clear pc;

end
%% run the option digester
types.standard_options={...
    'target_machine',       'which regular engine should we send data to for archival.' 
    'CS_reservation',       ' specify reservation to run on' 
    'CS_table',             ' the CS table on the scanner to use. Must be specified in streaming mode.' 
    'first_volume',         ' start reconstructing at volume N, The first volume will also be processed!'
    'last_volume',          ' stop reconstructing after volume N.'
    'chunk_size',           ' How many cs slices per slice job. Controls job run time. Ideally we shoot for 5-15 min job time.'
    'CS_preview_data',      ' save a pre recon of kspace and imgspace. Defaults to orthocenter, can specify =volume for whole volume. WILL NOT DO RECON'
    'roll_data',            ' pre-roll the data before reconstruction'
    'iteration_strategy',   ' the iteration/initalizaiton scheme to use, 10x5 by default. '
    're_init_count',        ' how many times will we be re-initalizing default 4(maybe this is bad because we do one more block of iterations than this implies)'
    'Itnlim',               'number of iterations, would like to rename to max_iterations. Probably have to chase this down in the code.'
    'TVWeight',             ' total variation? '
    'xfmWeight',            ' wavelet transform weight? '
    'hamming_window',       ' used in the creation of phmask'
    'skip_fermi_filter',    'do not do fermi_filtering of kspace before fft' 
    'fermi_w1',             ''
    'fermi_w2',             ''
    'fid_archive',          ' sends CS_fid to target_machine so we can run fid_archive on it there'
    };
types.beta_options={...
    'wavelet_dims',         '[filter_size,wave_scale] filter_size can be from 4 to 20, in steps of 2. wave_scale is the final wavelet scale. 4 is generally a good value, it can be increased for larger volumes, but it wont really change your image quality( up or down). We do need to take care that 2^wave_scale <= log2(dim_y/2^scale_count). We think 4 is a good wave scale count. '
    'wavelet_type',         ['One of -> ' strjoin({'Haar', 'Beylkin', 'Coiflet', 'Daubechies',...
    'Symmlet', 'Vaidyanathan','Battle'},':')]
    'process_headfiles_only',    ' skip image reconstruction and only process headfile(s)'
    'skip_target_machine_check', 'dont bother checking if target_machine is alive.' 
    };
types.planned_options={...
    'selected_scale_volume',' default 0, which volume set''s the scale '
    'slicewise_norm',       ' normalize the initial image by slice max instead of volume max'
    'slice_randomization',  ' randomize the slice procession'
    'convergence_threshold',''
    'keep_work',            ''
    'email_addresses',      ''
    'verbosity',            ''
    'scanner_user',         ' what user do we use to pull from scanner.'
    'live_run',             ' run the code live in matlab, igored when deployed.'
    };
options=mat_pipe_option_handler(varargin,types); clear varargin types;
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
% james normally attaches this to the "debug_mode" option, 
% with increasing values of debugging generating more and more output.
% at debug of 50 things which were errors start to become warnings.
options.verbose=1;
if options.debug_mode<10
    options.verbose=0;
end
log_mode = 2; % Log only to log file.
if options.verbose
    log_mode = 1; % Log to file and standard out/error.
end
if ~options.target_machine
    options.target_machine = 'delos';
end
% since options are defacto off, this should set inverse.
options.fermi_filter=~options.skip_fermi_filter; 
if ~options.fermi_w1
    options.fermi_w1 = 0.15;
end
if ~options.fermi_w2
    options.fermi_w2 = 0.75;
end
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
   elseif ~reg_match(options.CS_preview_data,'slice|volume')
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
        msg='keep_work and iteration_strategy are not tested together';
        if options.debug_mode>=50
            warning(msg);
            pause(5);
	else
	    error(msg); 
        end
    end
    options.iteration_strategy=strsplit(options.iteration_strategy,'x');
    ic=str2double(options.iteration_strategy(1));
    options.re_init_count=str2double(options.iteration_strategy(2))-1;
    options.Itnlim=ic*(options.re_init_count+1);
    options.iteration_strategy=strjoin(options.iteration_strategy,'x');
    clear ic;
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
if ~ischar(options.wavelet_type)
    %     'Haar', 'Beylkin', 'Coiflet', 'Daubechies',
    %           'Symmlet', 'Vaidyanathan','Battle'
    options.wavelet_type='Daubechies';
end
if numel(options.wavelet_dims)~=2
    options.wavelet_dims=[12,12];
end
%% Reservation/ENV support
active_reservation=get_reservation(options.CS_reservation);
options.CS_reservation=active_reservation;
cs_queue=CS_env_queue();
%% Determine where the matlab executables live
[cs_execs,cs_exec_set]=CS_env_execs();
%% Get workdir
scratch_drive=getenv('BIGGUS_DISKUS');
workdir=fullfile(scratch_drive,[runno '.work']);
log_file=fullfile(workdir,[ runno '_recon.log']);
% fid_path.local= fullfile(workdir,[runno '.fid']);
% fid_path.local= fullfile(workdir,'fid');
complete_study_flag=fullfile(workdir,['.' runno '.recon_completed']);
%% read system/scanner settings
% check that important things are found
%engine_constants = load_engine_dependency();
% scanner_constants = load_scanner_dependency(scanner_name);
the_workstation=wks_settings();
the_scanner=scanner(scanner_name);
if strcmp(options.target_machine,'localhost')
    options.skip_target_machine_check=1;
end
remote_workstation=wks_settings(options.target_machine);
% validate normal commands are functional 
%{
%
% TODO: integrate this in engine settings! this doesnt really belong here!
%   engine settings SHOULD include hints for this sort of trouble!
%
[s,sout]=system('puller_simple');
if s~=0 && ispc
    % if pc do special handling (annoying git-bash->windows pathing frustration)
    % ensure we have a functional bash command, and HOPE that will actually
    % work. If we dont have the right cmd specified insert a default guess.
    matlab_system_prefix='bash -c -- ';
    if isfield(engine_constants,'engine_app_matlab_system_prefix')
        matlab_system_prefix = engine_constants.engine_app_matlab_system_prefix;
    else
        engine_constants.engine_app_matlab_system_prefix = matlab_system_prefix;
    end    
    [s,sout]=system(sprintf('%s ', matlab_system_prefix, 'ls'));
    if s~=0
        error('cannot use terminal commands');
    end
end
%}
%% user configurable scanner user.
% make sure each mention of user will be set proper
% only partially implemented :D
legacy_scanners={'heike','kamy','onnes'};
su='';
if any(strcmp(legacy_scanners,scanner_name))
    su='omega';
else
    %{
    % SHOULD LET THIS BE UP TO SSH ! 
    if isempty(the_scanner.user)
        the_scanner.user=sys_user();
    end
    %}
end
if ~isempty(the_scanner.user)
    su=the_scanner.user;
end
if options.scanner_user
    su=options.scanner_user;
end
if ~isempty(su)
    options.scanner_user=su;
    the_scanner.user=su;
end
%% do main work and schedule remainder
if ~exist(complete_study_flag,'file')
    % only work if a flag_file for complete recon missing
    %% First things first: get specid from user!
    % Create or get one ready.
    recon_file = fullfile(workdir,[runno '_recon.mat']);
    param_file_name=sprintf('%s.param',runno);
    param_file_path=fullfile(the_workstation.recongui_paramfile_directory,...
        param_file_name);
    % this will only run if we havnt before BECAUSE we dont want to let
    % users re-write unintentionally, and we'll add these values quickly to
    % recon_file.
    if ~exist(recon_file,'file') && ~exist(param_file_path,'file')
        % basic call out to the gui program, instead of CS_GUI_mess or
        % specid 2 recon mat
        args=sprintf('%s %s %s',...
            the_workstation.file_path , ...
            scanner_name ,...
            param_file_name );
        %if ~ispc
        % add quotes after setting up args may need to waffle on the type
        % of quotes.
        args=sprintf('"%s"',args);
        %end
        gui_app=getenv('GUI_APP');
        if ~strcmp(gui_app,'')
            gui_cmd=sprintf('%s %s',getenv('GUI_APP') , args);
            [s,sout]=system(gui_cmd); assert(s==0,sout);
        else
            warning('GUI NOT SET archive info will not be saved');
        end
    end
    if exist(param_file_path,'file')
        gui_info=read_headfile(param_file_path,0);
    end
    %% Give options feedback to user, with pause so they can cancel
    fprintf('Ready to start! Here are your recon options:\n');
    fprintf('  (Ctrl+C to abort)\n');
    struct_disp(options,'ignore_zeros')
    if exist('gui_info','var')
        fprintf('Here are the recon gui settings\n');
        fprintf('  to adjust, delete %s\n',param_file_path);
        struct_disp(gui_info);
    end
    % wait until user affirms they like parameters as seen.
    while ~reg_match(...
            input(sprintf('Enter (Y)es to continue\n'),'s'), ...
            '^((y(es)?)|(c(ont(inue)?)?)[\s]*)$' ) 
        %{
        isempty( ...
            regexpi(input( ...
            sprintf('Enter (Y)es to continue\n'),'s'), ...
            '^((y(es)?)|(c(ont(inue)?)?)[\s]*)$','once') ...
            )
        %}
        pause(0.25);
    end
    %being a snot and leaving this pause even after the user says yes, 
    % in case they're extra hasty :P 
    forced_wait=3;
    if options.debug_mode>=50 
        forced_wait=0.1;
    end
    fprintf('Continuing in %g seconds ...\n',forced_wait);
    pause(forced_wait); 
    %% setup working folder, initialization info to log file, and create recon.mat
    if ~exist(workdir,'dir')
        mkdir_cmd = sprintf('mkdir "%s"',workdir);
        [s,sout]=system(mkdir_cmd); assert(s==0,sout);
    end
    recon_mat = matfile(recon_file,'Writable',true);
    recon_mat.matlab_path = matlab_path;
    % intentionally re-writing these params instead of avoiding it.
    % cannot directly access structs, so we have to pull headfile out.
    if matfile_missing_vars(recon_file,'headfile')
        headfile=struct;
    else
        headfile=recon_mat.headfile;
    end
    recon_mat.runno = runno;
    recon_mat.scanner_name = scanner_name;
    % TODO: generic for studdy/series but wee dont know how new sys will be
    % organized yet
    if strcmp(the_scanner.vendor,'agient')
        db_inplace('skipping to allow for failures');
        %{
        t=strsplit(scanner_data,'/');
        [scanner_patient,scanner_acquisition]=t{:};
        recon_mat.scanner_patient = scanner_patient;
        recon_mat.scanner_acquisition = scanner_acquisition;
        recon_mat.scanner_data=t;
        clear t;
        %}
    else 
        %scanner_data={scanner_data};
    end
    recon_mat.scanner_data=input_data;
    headfile.U_runno=runno;
    headfile.U_scanner=scanner_name;
    headfile=combine_struct(headfile,the_scanner.hf);
    recon_mat.the_scanner=the_scanner;
    recon_mat.remote_workstation=remote_workstation;
    headfile=combine_struct(headfile,the_workstation.hf);
    recon_mat.the_workstation=the_workstation;
    if exist('gui_info','var')
        gui_info=rmfield(gui_info,'comment');
        headfile=combine_struct(headfile,gui_info,'U_');
    end
    headfile.B_recon_type = recon_type;
    % now stuff it back in the mfile
    recon_mat.headfile=headfile;
    recon_mat.study_workdir = workdir;
    recon_mat.scale_file = fullfile(workdir,[ runno '_4D_scaling_factor.float']);
    recon_mat.fid_tag_file = fullfile(workdir, [ '.' runno '.fid_tag']);
    if ~exist(log_file,'file')
        % Initialize a log file if it doesn't exist yet.
        [s,sout]=system(['touch ' log_file]); 
        % why is this important? lets not bother?
        %assert(s==0,sout);
    end
    ts=fix(clock);
    t=datetime(ts(1:3));
    month_string = month(t,'name');
    start_date=sprintf('%02i %s %04i',ts(3),month_string{1},ts(1));
    start_time=sprintf('%02i:%02i',ts(4:5));
    user = sys_user();
    log_msg=sprintf('\n');
    log_msg=sprintf('%s----------\n',log_msg);
    log_msg=sprintf('%sCompressed sensing reconstruction initialized on: %s at %s.\n',log_msg,start_date, start_time);
    log_msg=sprintf('%s----------\n',log_msg);
    %{
    log_msg=sprintf('%sScanner study: %s\n',log_msg, scanner_patient);
    log_msg=sprintf('%sScanner series: %s\n',log_msg, scanner_acquisition);
    %}
    log_msg=sprintf('%sScanner data: %s\n',log_msg, input_data);
    log_msg=sprintf('%sUser: %s\n',log_msg,user);
    log_msg=sprintf('%sExec Set: %s\n',log_msg,cs_exec_set);
    yet_another_logger(log_msg,log_mode,log_file);
    recon_mat.log_file = log_file;
    %% Test ssh connectivity using our perl program which has robust ssh handling.
    %{
    puller_test=sprintf('puller_simple -o -f file %s ../../../../home/vnmr1/vnmrsys/tablib/%s %s/%s',...
        the_scanner.name,options.CS_table,workdir,options.CS_table);
    %}
    puller_test=sprintf('puller_simple -u %s -o -f file %s /home/%s/.bashrc %s_%s_connection_check',...
        options.scanner_user, the_scanner.name, options.scanner_user, the_scanner.name, options.scanner_user);
    [s,sout]=system(puller_test,'-echo');
    assert(s==0,'Failed to contact scanner, %s',sout);
    
    if ~options.skip_target_machine_check
        puller_test=sprintf('puller_simple -u %s -o -f file %s activity_log.txt .%s_%s_activity_log.txt ',...
            sys_user(),options.target_machine,options.target_machine,sys_user());
        fprintf('Test target_machine (%s) connection...\n',options.target_machine);
        [s,sout]=system(puller_test,'-echo');
        if s~=0
            error('Problem on testing of connection to %s\n%s\n',...
                options.target_machine,sout);
        else
            fprintf('Connect to %s succesful\n',options.target_machine);
        end
    end
    %% Second First things first: determine number of volumes to be reconned
    %%% TODO: enhance this section to TRY puller_simple FIRST
    % IF it should fail, then we worry about are we
    % local/streaming/static... Then we get specific in our data
    % definitions.
    % we probably still want to use data_definition_cleanup so we have the
    % "main" thing to transfer with puller_simple.

    %{
    % if we're a volume_index scan, and we dont exist locally, we need to get the
    % volume index immediately.This has a SIGNIFICANT order of operations
    % challenge. We need to clean up the data definition, AND get the scan
    % mode. But with a volume_index file, we may have an existing local
    % file which is not data, generating confusion, and complicating the
    % order of things.
    if reg_match(input_data,'volume_index.txt') 
        if ~exist(input_data,'file')
            index_fetch=sprintf('puller_simple -r -f file -u %s %s %s %s.work',...
                options.scanner_user, the_scanner.name, path_convert_platform(input_data,'linux'), runno);
        else
            index_fetch=sprintf('cp -p %s %s ',  input_data, workdir);
        end
        local_index=fullfile(workdir,'volume_index.txt');
        %if ~exist(local_index,'file')
        % we always grab the index because it is how we know how much data
        % will be done. It is supposed to be prepopulated with numbers on
        % the scanner, and after each scan is done the data file is filled
        % in
        [s,sout] = system(index_fetch);
        assert(s==0,sout);
        %end
    end
    % cleans up user input to solidly hold REMOTE file locations
    scan_data_setup=the_scanner.data_definition_cleanup(input_data);
    % becuase i dont want to make data_definition_cleanup complicated, we
    % load volume index externally, maybe we can load it and pass it as
    % input data? and that would be more reasonable?
    if ~isfield(scan_data_setup,'fid') && reg_match(input_data,'volume_index.txt')
        local_index=load_index_file(local_index);
        if ~path_is_absolute(local_index.fid{1})
            % local_index.fid = cellfun(@(c) fullfile(scan_data_setup.main,c), local_index.fid)
            idx_ready = cellfun(@(c) ~isempty(c),local_index.fid);
            full_paths = cellfun(@(c) fullfile(scan_data_setup.main,c), local_index.fid, 'UniformOutput', false);
            local_index.fid(idx_ready) = full_paths(idx_ready);
        end
        scan_data_setup.fid=local_index.fid;
    end
    %}
    if ~reg_match(input_data,'volume_index.txt') 
        scan_data_setup=the_scanner.data_definition_cleanup(input_data);
    else
        scan_data_setup=refresh_volume_index(input_data,the_scanner,workdir,options);
    end
    recon_mat.scan_data_setup=scan_data_setup;

    % given a "fid" file path which is remote OR local, figure out the
    % current status, and return the local, remote and/or streaming file
    % paths
    [data_mode,fid_path]=get_data_mode(the_scanner,workdir,scan_data_setup.fid);

    % old rad_mat var was kspace_data_path, but it was for the local
    % file, we only use the local file when it exists, so i'm not
    % saving it separately
    if matfile_missing_vars(recon_file,'fid_path')
        recon_mat.fid_path=fid_path;
    else
        % if we've already collected fid_path REFUSE to update remotes by
        % reading back previous and only udpating current.
        fid_path_prev=recon_mat.fid_path;
        fid_path_prev.current=fid_path.current;
        recon_mat.fid_path=fid_path_prev;
        clear fid_path_prev;
    end
    % fid_consistency gets a header of data and a few bytes too saving it in the fid_tag_file
    % we use that to get some scanner details
    test_fid=fid_path.current;
    if reg_match(test_fid,'NO_FILE')
        test_fid=fid_path.remote;
    end
    if ~the_scanner.fid_consistency(test_fid, recon_mat.fid_tag_file,0)
        % may want to skip fid consistency for local becuase we have the 
        % whole thing to work on ?
        % decided against that becuase if we're local we'd want to be
        % consistent too, and its an inexpensive check
        log_msg=sprintf('FID consistency check failed!\n');
        yet_another_logger(log_msg,3,log_file,1);
        if isdeployed; quit force; else; error(log_msg); end
    end
    % returing S_hdr for now for convenience, in the future all important
    % bits will be filed under acq_hdr, and that will be removed.
    [acq_hdr,S_hdr]=load_acq_hdr(the_scanner,recon_mat.fid_tag_file);
    % so we wont have to re-load the scanner info later, we'll stuff it
    % into the master file.
    recon_mat.scan_header=S_hdr;
    recon_mat.dim_x=acq_hdr.ray_length;
    recon_mat.bytes_per_block=acq_hdr.bytes_per_block;
    recon_mat.rays_per_block=acq_hdr.rays_per_block;
    % check for multi-input files vs multi-volume in one file
    if prod(acq_hdr.dims.Sub('et')) > 1
        recon_mat.ray_blocks=acq_hdr.ray_blocks;
    elseif iscell(scan_data_setup.fid) && numel(scan_data_setup.fid) > 1
        recon_mat.ray_blocks = numel(scan_data_setup.fid);
    else
        recon_mat.ray_blocks = 1;
    end
    recon_mat.kspace_data_type=acq_hdr.data_type;
    % load basic info from the header we scrapped during the
    % fid_consistency check. Why was this being done here? if seems this
    % should MOVE 
    % 
    % vars not obviously used here
    % npoints(it is used to generate dim_x) dim_x is not REALLY needed
    %     here!!! we should defer it until just prior to scheduling our
    %     volume workers.
    % nblocks (used to get n_volumes)
    % bitdepth
    % bbytes
    % --
    % ntraces is used to find remote CS table(isnt this always npoints/2
    %     for agilent)
    % 
    if exist('agilent_specific','var')
        % OBSOLETE CODE will be removed soon once these are abstracted away
        varlist='npoints,nblocks,ntraces,bitdepth,bbytes,dim_x';
        missing=matfile_missing_vars(recon_file,varlist);
        if missing>0
            [recon_mat.npoints,recon_mat.nblocks,recon_mat.ntraces,recon_mat.bitdepth,recon_mat.bbytes,~,~] = load_fid_hdr(recon_mat.fid_tag_file);
            % formerly protected dim_x by rounding BUT THAT IS BAD!
            % If it is EVER fractional we want to throw errors!
            dx = recon_mat.npoints/2;
            if floor(dx) ~= dx
                log_msg=sprintf('ERROR pulling dim_x from fid hdr field npoints!\n');
                yet_another_logger(log_msg,3,log_file,1);
                if isdeployed; quit force; else; error(log_msg); end
            end
            recon_mat.dim_x=dx;
            vs=strsplit(varlist,',');
            for vn=1:numel(vs)
                if isnumeric(recon_mat.(vs{vn})) % && ~ischar(m.(vs{vn}))
                    recon_mat.(vs{vn})=double(recon_mat.(vs{vn}));
                end
            end; clear vs vn dx missing;
        end
    end
    %% get a cs table into work folder
    % first we see if we've got one, otherwise we check if user specified
    % one
    tables_in_workdir=dir([workdir '/*CS*_*x*_*']);
    if options.debug_mode >=150 && strcmp(the_scanner.vendor,'mrsolutions') ...
        && isempty(tables_in_workdir)
        db_inplace(mfilename,'manual cs_table faking ');
        % wkdir='D:\workstation\scratch\N00009.work';
        md=[acq_hdr.dim_Y,acq_hdr.dim_Z];
        m=ones(md);md=unique(md);
        md=regexprep(num2str(md),'\s+','x');
        tn=sprintf('stream_table_CS%s_1x_pa18_pb54.txt',md);
        save_cs_stream_table(m,fullfile(workdir,tn));
        tables_in_workdir=dir([workdir '/*CS*_*x*_*']);
    end
    local_table_path='';
    options.CS_table=path_convert_platform(options.CS_table,'linux');
    if ~isempty(tables_in_workdir)
        [~,n,e]=fileparts(options.CS_table);TAB_N=[n,e];clear n e;
        if ischar(options.CS_table) && ~strcmp(TAB_N,tables_in_workdir(1).name)
            % have user specified, lets error if they're different
            error('existing table in working folder doesnt match user specified table! \nuser:\t%s\nworkdir:\',...
                TAB_N, tables_in_workdir(1).name)
        elseif numel(tables_in_workdir)>1
            error('Multiple CS tables in work dir! %s',workdir);
        end
        options.CS_table=tables_in_workdir(1).name;
        local_table_path=fullfile(workdir,options.CS_table);
        log_msg = sprintf('Using first CS_table found in work directory: ''%s''.\n',options.CS_table);
    end
    % set local procpar location, and if possible fetch it now
    if exist('agilent_specific','var')
        procpar_file = fullfile(workdir,'procpar');
        procpar_file_legacy = fullfile(workdir,[runno '.procpar']);
        if exist(procpar_file_legacy,'file')
            warning('Legacy procpar file name detected!');
            procpar_file=procpar_file_legacy;
        end;clear procpar_file_legacy;
        recon_mat.procpar_file = procpar_file;
    end
    % local_table_path='test';warning('test hard set table');
    if ~strcmp(data_mode,'streaming') && isempty(local_table_path) ...
            && strcmp(the_scanner.vendor,'agilent')
        %%% local or static mode
        if exist('agilent_specific','var')
            %%%
            % PROBLEM, agilent codes the petable, but so far, i dont see
            % how we'd slip that into our mrsolutions data!
            %%%
            % WARNING THIS HASNT BEEN UPDATED SINCE scanner
            % patient/acquisition were joined to scanner_data
            % 
            if ~exist(procpar_file,'file')
                % considering deactivating this so all recons will proceed through the same
                % code path
                % datapath=fullfile('/home/mrraw',scanner_patient,[scanner_acquisition '.fid']);
                % mode =2; % Only pull procpar file
                % puller_glusterspaceCS_2(runno,datapath,scanner_name,workdir,mode);
                pull_cmd=sprintf('puller_simple -oer -f file -u %s %s %s/%s.fid/procpar %s.work',...
                    options.scanner_user, the_scanner.name, scanner_patient, scanner_acquisition, runno);
                [s,sout] = system(pull_cmd);
                assert(s==0,sout);
            end
            remote_table_path=procpar_get_petableCS(procpar_file);
        end
        [~,n,e]=fileparts(remote_table_path);
        options.CS_table=sprintf('%s%s',n,e);
        local_table_path=fullfile(workdir,options.CS_table);
    else
        % formerly this was only for streaming, but it seems like we'd like
        % to use it more often, eg for our new mrsolutions console where we
        % dont know how the table will be connected to the data.
        %if strcmp(data_mode,'streaming')
        if ischar(options.CS_table)
            log_msg = sprintf('Per user specification, using CS_table ''%s''.\n',options.CS_table);
            yet_another_logger(log_msg,log_mode,log_file);
            if isempty(local_table_path)
                [~,n,e]=fileparts(options.CS_table);
                local_table_path=fullfile(workdir,[n e]); clear n e;
            end
            if ~path_is_absolute(options.CS_table)
                remote_table_path=fullfile(the_scanner.skip_table_directory,options.CS_table);
            else
                remote_table_path=options.CS_table;
            end
        else % if islogical options.CS_table
            % streaming you had to tell the cs table, find_cs_table might work,
            % but its not well tested
            %remote_table_path=find_cs_table(the_scanner,m.ntraces,typical_pa,typical_pb);
            remote_table_path=find_cs_table(the_scanner,acq_hdr.dims.Sub('P'),typical_pa,typical_pb);
            [~,n,e]=fileparts(remote_table_path);
            if ~path_is_absolute(remote_table_path(1))
                remote_table_path=fullfile(the_scanner.skip_table_directory,remote_table_path);
            end
            options.CS_table=sprintf('%s%s',n,e);
            local_table_path=fullfile(workdir,options.CS_table);
            % we have either found a cs table in work folder, or we have a procpar,
            % and pulled the location from there, if it is not in the work dir we
            % need to fetch it now....
            % new param for search up the table
            % scanner_skip_table_directory
        end
    end
    if ~exist(local_table_path,'file')
        if exist('remote_table_path','var')
            % convert a windows-path to linuxly becuase we always pull from
            % linuxly
            if path_is_windows(remote_table_path) && ~exist(remote_table_path,'file')
                % NO support for spaces :p
                remote_table_path=path_convert_platform(remote_table_path,'linux');
                %{
                remote_table_path([1,2])=remote_table_path([2,1]);
                remote_table_path(1)='/';
                remote_table_path=strrep(remote_table_path,'\','/');
                %}
            end
            if ~exist(remote_table_path,'file')
                table_fetch=sprintf('puller_simple -oer -f file -u %s %s %s %s.work',...
                    options.scanner_user, the_scanner.name, remote_table_path, runno);
            else
                table_fetch=sprintf('cp -p %s %s',remote_table_path,local_table_path);
            end
            [s,sout] = system(table_fetch);
            assert(s==0,sout);
        else
            error('need CS table to proceed, must have table resolve logic fault! local path set, but remote is not local(%s)',local_table_path)
        end
    end
    %% process skiptable/mask set up common part of headfile output
    cache_folder=fullfile(getenv('WORKSTATION_DATA'),'petableCS');
    [table_integrity,last_path]=cache_file(cache_folder,local_table_path);
    if ~table_integrity
        warning('CS table was updated! Old file was preserved as %s',last_path);
        pause(3);
    end
    % add sktiptable/mask stuff to our recon.mat
    % we do check if we've done this before using the missing matfile check
    varlist=['dim_y,dim_z,n_sampled_lines,sampling_fraction,mask,'...
        'CSpdf,phmask,recon_dims,original_mask,original_pdf,original_dims,nechoes,n_volumes'];
    missing=matfile_missing_vars(recon_file,varlist);
    if missing>0
        [recon_mat.dim_y,recon_mat.dim_z,recon_mat.n_sampled_lines,recon_mat.sampling_fraction,recon_mat.mask,recon_mat.CSpdf,recon_mat.phmask,recon_mat.recon_dims,...
            recon_mat.original_mask,recon_mat.original_pdf,recon_mat.original_dims] = process_CS_mask(local_table_path, recon_mat.dim_x, options.hamming_window, options.debug_mode);
        recon_mat.nechoes = 1;
        if recon_mat.ray_blocks == 1
            % n_sampled_lines is precisely the count from the cs mask
            recon_mat.nechoes = double(recon_mat.rays_per_block)/recon_mat.n_sampled_lines;
            recon_mat.n_volumes = recon_mat.nechoes;
        else
            recon_mat.n_volumes = recon_mat.ray_blocks;
            % acq_hdr.ray_blocks_per_volume=1
            % acq_hdr.rays_per_volume=acq_hdr.rays_per_block;
        end
        %{ 
        vs=strsplit(varlist,',');
        for vn=1:numel(vs)
            m.(vs{vn})=double(m.vs{vn});
        end; clear vs vn
        %}
        % Please enhance later to not be so clumsy (include these variables
        % in the missing variable list elsewhere in this function.
        % dataBufferHeafile <- bh
        bh=struct;
        original_dims=recon_mat.original_dims;
        %% 
        bh.dim_X=original_dims(1);
        bh.dim_Y=original_dims(2);
        bh.dim_Z=original_dims(3);
        bh.A_dti_vols=recon_mat.n_volumes;
        bh.A_channels = 1;
        bh.A_echoes = recon_mat.nechoes;
        
        bh.CS_working_array=recon_mat.recon_dims;
        bh.CS_sampling_fraction = recon_mat.sampling_fraction;
        bh.CS_acceleration = 1/recon_mat.sampling_fraction;

        %bh.U_runno = volume_runno;
        headfile=combine_struct(bh,recon_mat.headfile);
        recon_mat.headfile=headfile;
        clear bh
    end
    %% Check all n_volumes for incomplete reconstruction
    %WARNING: this code relies on each entry in recon status being
    %filled in. This should be fine, but take care when refactoring.
    recon_status=zeros(1,recon_mat.n_volumes);
    vol_strings=cell(1,recon_mat.n_volumes);
    for vn = 1:recon_mat.n_volumes
        vol_string =sprintf(['%0' num2str(numel(num2str(recon_mat.n_volumes-1))) 'i' ],vn-1);
        volume_runno = sprintf('%s_m%s',runno,vol_string);
        volume_flag=sprintf('%s/%s/%simages/.%s_send_archive_tag_to_%s_SUCCESSFUL', ...
            workdir,volume_runno,volume_runno,volume_runno,options.target_machine);
        vol_strings{vn}=vol_string;
        [stage_n,~,pc]=volume_status(fullfile(workdir,volume_runno),volume_runno);

        % [~,~,pc]=check_status_of_CSrecon(fullfile(workdir,volume_runno),volume_runno);
        if exist(volume_flag,'file') && pc >= 100
            recon_status(vn)=1;
        end
        if isnumeric(options.last_volume) && options.last_volume
            if vn~=1 && vn>options.last_volume
                break;
            end
        end
    end
    %reconned_volumes=find(recon_status);
    %reconned_volumes_strings=vol_strings(find(recon_status));
    %num_reconned = length(reconned_volumes); % For reporting purposes
    unreconned_volumes=find(~recon_status);
    unreconned_volumes_strings=vol_strings(find(~recon_status));
    num_unreconned = length(unreconned_volumes); % For reporting purposes
    clear volume_flag vol_string vol_strings vn;
    %% Let the user know the status of thesave recon.
    log_msg =sprintf('%i of %i volume(s) have fully reconstructed.\n',recon_mat.n_volumes-num_unreconned,recon_mat.n_volumes);
    yet_another_logger(log_msg,log_mode,log_file);
    %% Do work if needed, first by finding input fid(s).
    if (num_unreconned > 0)
        % insert options to matfile.
        recon_mat.options = options;
        running_jobs = '';
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
            mkdir_s=zeros([1,4]);
            dir_cell={volume_dir,vol_sbatch_dir};
            if ~exist(vol_sbatch_dir,'dir')
                %%% mkdir commands pulled into here from check status,
                fprintf('Making voldir,sbatch,work,images,directories\n');
                for dn=1:numel(dir_cell)
                    [mkdir_s(dn), dir_cell{dn}]=system(sprintf('mkdir "%s"', dir_cell{dn}));
                end
                % becuase mgre fid splitter makes directories, we dont do this
                % check for mgre
                if(sum(mkdir_s)>0) &&  (recon_mat.nechoes == 1)
                    strjoin(dir_cell(mkdir_s~=0),'\n')
                    log_msg=sprintf('error with mkdir for %s\n will need to remove dir %s to run cleanly. ', ...
                        volume_runno,volume_dir);
                    yet_another_logger(log_msg,log_mode,log_file,1);
                    if isdeployed
                        quit force
                    else
                        error(log_msg);
                    end
                end
            end
            % vm is "volume manager"
            vm_slurm_options=struct;
            vm_slurm_options.v=''; % verbose
            vm_slurm_options.s=''; % shared; volume manager needs to share resources.
            
            % memory requested; volume manager only needs a miniscule amount.
            %--In theory only! For yz-array sizes > 2048^2, loading the
            % data of phmask, CSmask, etc can push the memory past the former 512MB
            vm_slurm_options.mem=2048;
            vm_slurm_options.p=cs_queue.gatekeeper;% cs_full_volume_queue; % For now, will use gatekeeper queue for volume manager as well
            vm_slurm_options.job_name = [volume_runno '_volume_manager'];
            %vm_slurm_options.reservation = active_reservation;
            % using a blank reservation to force no reservation for this job.
            vm_slurm_options.reservation = ''; 
            volume_manager_batch = fullfile(volume_dir,'sbatch',[ volume_runno '_volume_manager.bash']);
            vm_args=sprintf('%s %s %i %s',recon_file,volume_runno, volume_number,workdir);
            vm_cmd = sprintf('%s %s %s ', cs_execs.volume_manager, ...
                matlab_path, vm_args);
            %%% James's happy delay patch
            if ~options.process_headfiles_only && ~options.live_run
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
                log_msg =sprintf('Initializing Volume Manager for volume %s (SLURM jobid(s): %s).\n', ...
                    volume_runno,c_running_jobs);
                yet_another_logger(log_msg,log_mode,log_file);
            elseif options.live_run
                a=strsplit(vm_args);
                volume_manager_exec(a{:});clear a;
            end
        end
    end
end % This 'end' belongs to the scanner_patient_flag check

if options.fid_archive && local_or_streaming_or_static==3
    % puller overwrite option
    poc='';
    % fid_archive overwrite option
    foc='';
    if options.overwrite
        poc='-eor';
        foc='-o';
    end
    error('scanner_data udpate required');
    pull_cmd=sprintf('puller_simple -u %s %s %s %s/%s* %s.work;fid_archive %s %s %s', ...
        options.scanner_user, poc,scanner_name,input_data,runno,foc,user,runno);
    ssh_and_run=sprintf('ssh %s@%s "%s"',sys_user(),options.target_machine,pull_cmd);
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

function [databuffer,optstruct] = CS_GUI_mess(scanner,runno,recon_file)
errror('obsolete function');
    % a hacky patch around the trouble that the specid_to_recon_file
    % function is damned dirty.
    % one trouble is that databuffer is thrown around as a struct, and that
    % is not right at all, its supposed to be a (large_array) object which many
    % functions are allowed to update the contents of.
    % databuffer=large_array;
    databuffer.engine_constants = load_engine_dependency();
    databuffer.scanner_constants = load_scanner_dependency(scanner);
    % Wanted to Intentionally omit U_runno because it'll only be right for single
    % volumes. 
    % Unfortunately it's part of sanity checking in gui_info_collect'
    databuffer.headfile.U_runno = runno;
    databuffer.headfile.U_scanner = scanner_name;
    databuffer.input_headfile = struct; % Load procpar here.
    databuffer.headfile = combine_struct(databuffer.headfile,databuffer.scanner_constants);
    databuffer.headfile = combine_struct(databuffer.headfile,databuffer.engine_constants);
    optstruct.testmode = false;
    optstruct.debug_mode = 0;
    optstruct.warning_pause = 0;
    optstruct.param_file =[runno '.param'];
    gui_info_collect(databuffer,optstruct);
end

function recon_mat = specid_to_recon_file(scanner,runno,recon_file)
errror('obsolete function');
warning('THIS FUNCTION IS VERY BAD');
% holly horrors this function is bad form!
% it combines several disjointed programming styles.
% the name is also terrible!
% Now I've made it worse by removing the core ugly into it's own function
recon_mat = matfile(recon_file,'Writable',true);
if ~isstruct(scanner)
    [databuffer,optstruct] = CS_GUI_mess(scanner,runno,recon_file);
else
    databuffer=scanner;
    optstruct=runno;
end
recon_mat.databuffer = databuffer;
recon_mat.optstruct = optstruct;
end
