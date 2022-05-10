function [ starting_point ,log_msg, vol_status, extended] = volume_status( ...
    volume_dir,volume_runno,the_scanner,volume_number,input_data,bbytes )
% check status of an individual volume in the cs recon.
%%% NOTEABLY bbytes can be omitted.
%
%% Preflight checks
% Determining where we need to start doing work, setting up folders as
% needed.
%
% 0 : Source fid not ready, run gatekeeper.
% 1 : Extract fid.
% 2 : Run volume setup. (create workspace.mat and .tmp files)
% 3 : Schedule slice jobs.
% 4 : Run volume cleanup.
% 5 : Send volume to workstation and write recon_completed flag.
% 6 : All work done; do nothing.
%
% Required inputs:
%   workdir (volume_subfolder, so '../volume_runno NOT '../volume_runno/work/')
%   volume_runno (usually runno_mXX)
%
% Required for earlier check calls, if absent when needed, will return
% starting_point = 0:
%   scanner
%   runno
%   study
%   series
%   bbytes (bytes per fid block)
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

% would be cool to define the different checks, and then loop over the
% array of states, performing each test.
work_subfolder = fullfile(volume_dir, 'work');
stage_n=1;
%% is this chunk of data ready on scanner
status_setup(stage_n).code='Acquistion in progress on scanner.';
status_setup(stage_n).pct=1;
if exist('the_scanner','var') ...
    && exist('volume_number','var') ...
    && exist('input_data','var')
    if ~isa(the_scanner,'scanner')
        warning('passed name instad of scanner settings object, trying to load');
        scanner_name=the_scanner;
        the_scanner=scanner(scanner_name);
    end
    if ~exist('bbytes','var'); bbytes=0; end
    status_setup(stage_n).check=@() check_remote_fid(work_subfolder,volume_runno,the_scanner,input_data,volume_number,bbytes);
else
    % cannot check on scanner without params, so we will consider this
    % status incomplete
    status_setup(stage_n).check=@() 0;
end
stage_n=stage_n+1;
%% have we pulled this chunk of data to this ppsystem
status_setup(stage_n).code='Extract fid.';
status_setup(stage_n).pct=4;
if ~exist('input_data','var')
    status_setup(stage_n).check=@() check_local_fid(work_subfolder,volume_runno);
elseif exist('the_scanner','var')
    status_setup(stage_n).check=@() check_local_fid(the_scanner.fid_file_local(work_subfolder,input_data));
else
    % bogus condition, just a placeholder
    status_setup(stage_n).check=@() check_local_fid(work_subfolder,volume_runno,input_data);
end
stage_n=stage_n+1;
%% has the workspace.mat and tmp file been created
status_setup(stage_n).code='Run volume setup. (create workspace.mat and .tmp files)';
status_setup(stage_n).pct=0;
status_setup(stage_n).check=@() check_vol_setup(work_subfolder,volume_runno);
stage_n=stage_n+1;
%% have we reconstucted the cs_recon slices
status_setup(stage_n).code='Slice jobs.';
status_setup(stage_n).pct=90;
status_setup(stage_n).check=@() check_recon_slices(volume_dir,volume_runno);
stage_n=stage_n+1;
%% have the reconstructed cs slices been written out as image slices, what
% about the headfile
status_setup(stage_n).code='volume cleanup.';
status_setup(stage_n).pct=3;
status_setup(stage_n).check=@() check_img(volume_dir,volume_runno);
stage_n=stage_n+1;
%% have we copied image slices to our dest system
% send final headfile, and send archive tag file are integrated to this
% step at 0.1% each
status_setup(stage_n).code='Send volume to workstation and write recon_completed flag.';
status_setup(stage_n).pct=2;
status_setup(stage_n).check=@() send_vol_is_complete(volume_dir,volume_runno);
%% stage setup ready, loop through (backwards) integratnig vol_status
vol_status=100;% starting at complete, keep working it down. 
% current working params for each volume status
% stg6 100 
% stg5 0.1 = send tag& write headfile(including procpar)
% stg5 1.8 = send image
% stg5 0.1 = send headfile
% stg4   3   = write raw image slices
% stg3  90   = reconstruct CS slices
% stg2   4   = transfer/extract volume fid
% stg1   1   = acquisition on scanner

extended=struct;
% vol status is what % from 0-100 are we. 
% have to assign each stage some % it takes. lets pretend that only slices 
% matter, and they take 90% of the work.
stage_fraction=0;
for starting_point=numel(status_setup):-1:1
    stage_fraction=status_setup(starting_point).check();
    if isstruct(stage_fraction)
        extended=stage_fraction;
        clear stage_fraction;
        stage_fraction=extended.ready;
    end
    if stage_fraction==1
        break;
    end
    vol_status=vol_status-(1-stage_fraction)*status_setup(starting_point).pct;
end
% detect 0 work done
if starting_point==1 && stage_fraction==0
    starting_point=0;
end
% detect all work done
if starting_point==numel(status_setup) && stage_fraction==1
    % couldn't do this above becuase the all done check was not clear, if
    % it becomes clear i can stuff it into a check function
    stage_n=stage_n+1;
    status_setup(stage_n).code='All work done; do nothing.';
    status_setup(stage_n).pct=0;
    status_setup(stage_n).check=@() 1;
    starting_point=starting_point+1;
end

% vol_status=sprintf('%s',status_codes{starting_point+1},vol_status);
%log_msg =sprintf('Starting point for volume %s: Stage %i. %s\n',volume_runno,starting_point,status_codes{starting_point+1});
log_msg =sprintf('Starting point for volume %s: Stage %i. %s\n',volume_runno,starting_point,status_setup(starting_point+1).code);

end
%%%
%%% individual stages check functions
%%%
function hf_status=is_headfile_complete(headfile)
hf_status=0;
if ~exist(headfile,'file')
    return;
end
BytesPerKiB=2^10;
hf_minKiB=20;
hfinfo=dir(headfile);
if hfinfo.bytes>hf_minKiB*BytesPerKiB
    hf_status=1;
end
end

function send_vol_status=send_vol_is_complete(volume_dir,volume_runno)
    % this 2 pct represents processing the procpar, and images and headfile
    % to dest engine. We could break this down further, but its probably
    % not worth it. eg, 1.8% is send data, 0.1% is proces procpar, 0.1% is
    % send procpar.
    % 
    % this doesnt have to be a 2, it is just has to internally sum up each
    % portion to some value, and return the fraction of that value we
    % completed.
    % Externally that'll be scaled to the "vol_send percent" which was 2 as
    % of this writing
    vol_status=2;
    %% Check for archive_ready sent flag.
    % Previously checked for recon_completed, but that has since been changed.
    send_archive_tag = fullfile(volume_dir,sprintf('%simages',volume_runno), ...
        sprintf('.%s_send_archive_tag_to_*_SUCCESSFUL',volume_runno));
    send_archive_tag=wildcard_tag_finder(send_archive_tag);
    %% check headfile is complete
    headfile=fullfile(volume_dir,sprintf('%simages',volume_runno), ...
        sprintf('%s.headfile',volume_runno));
    headfile_complete=is_headfile_complete(headfile);
    if ~exist(send_archive_tag,'file') || ~headfile_complete
        vol_status=vol_status-0.1;
    end
    %% Check sent images
    send_images=fullfile(volume_dir,sprintf('%simages',volume_runno), ...
        sprintf('.%s_send_images_to_*_SUCCESSFUL',volume_runno));
    send_images=wildcard_tag_finder(send_images);
    if ~exist(send_images,'file')
        vol_status=vol_status-1.8;
    end
    %% check sent headfile
    %send_headfile='FILLMEINTWO';.T00020_m0_send_headfile_to_delos_SUCCESSFUL
    send_headfile=fullfile(volume_dir,sprintf('%simages',volume_runno), ...
        sprintf('.%s_send_headfile_to_*_SUCCESSFUL',volume_runno));
    send_headfile=wildcard_tag_finder(send_headfile);
    if ~exist(send_headfile,'file')
        vol_status=vol_status-0.1;
    end
    send_vol_status=vol_status/2;
end

function img_slice_status=check_img(volume_dir,volume_runno)
   %% check saved slice data
    images_dir = fullfile(volume_dir,[volume_runno 'images']);
    if ~exist(images_dir,'dir')
        finished_slices_count = 0;
    else
        finished_slices = dir( [images_dir '/*.raw' ]);
        finished_slices_count = length(finished_slices(not([finished_slices.isdir])));
        if finished_slices_count==0
            finished_slices = dir( [images_dir '/*.fp32' ]);
            finished_slices_count = length(finished_slices(not([finished_slices.isdir])));
        end
        headfile_exists = numel(dir( [images_dir '/*.headfile' ]));
    end
    if (finished_slices_count == 0) || (~headfile_exists)
        % We assume that all the raw files were written at once correctly
        % with the headfile written after acting as a "done writing" flag.
        img_slice_status=0;
    else
        img_slice_status=1;
    end
end

function recon_slice_status = check_recon_slices(volume_dir,volume_runno)
% Check .tmp file to see if all CS slices have reconned (note these
% are not image slices)
work_subfolder = fullfile(volume_dir, 'work');
temp_file = fullfile(work_subfolder, [ volume_runno '.tmp']);
% the amount of slices remaining as a fraction
recon_slice_incomplete = 1;
% This might be acceptable to search for inside the volume_dir
% instead of hardcoding to some format.
% Future thought...
setup_file = fullfile(volume_dir, [ volume_runno '_setup_variables.mat']);
if exist(temp_file,'file') ...
        && exist(setup_file,'file')
    % Need to remember that we are going to add the headersize as the first bytes
    tmp_header = load_cstmp_hdr(temp_file);
    try
        a = who('-file',setup_file,'recon_file');
        if size(a)
            % load(setup_file,'recon_file');clear a;
            sf=matfile(setup_file);
            recon_file=sf.recon_file;
        end; clear a sf;
    catch
        warning('Setupfile didn''t code recon_file old recons in progress should use the old code');
    end
    if exist(recon_file,'file')
        rf=matfile(recon_file);
        options=rf.options;
        slices_remaining = length(find(tmp_header<options.Itnlim));
        recon_slice_incomplete=slices_remaining/numel(tmp_header);
    else
        error('couldnt find recon file');
    end
end
%{
if ~exist('recon_file','var') ...
        && exist('runno','var') && ~exist('agilent_study','var')
    recon_file = fullfile(volume_dir, '..',[ runno '_recon.mat']);
    rf=matfile(recon_file);
    scanner_acquisition=rf.scanner_acquisition;
    agilent_study=rf.agilent_study;
    scanner_name=rf.scanner_name;
    bbytes=rf.bbytes;
end
%}
recon_slice_status=1-recon_slice_incomplete;
end

function vol_setup_status=check_vol_setup(work_subfolder,volume_runno)
% Check for a complete workspace file
workspace_file = fullfile(work_subfolder,[volume_runno,'_workspace.mat']);
try
    % Need to try to load an arbitrary variable from the work file
    % Why doesnt an exist check work here?
    % How about a var listing using
    %   whos('-file',workspace_file)
    varinfo=whos('-file',workspace_file);
catch
end
if ~exist('varinfo','var') ...
        || ( ~ismember('imag_data',{varinfo.name}) ...
        || ~ismember('real_data',{varinfo.name}) )
    vol_setup_status=0;
else
    vol_setup_status=1;
end
end

function fid_transfer_status=check_local_fid(varargin)
if nargin >= 2
    error('incomplete thought');
    work_subfolder=vargin{1};
    volume_runno=varargin{2};
    input_data=varargin{3};
elseif nargin==1
    input_data=varargin{1};
end
choices={};
if exist('input_data','var')
    %[~,n,e]=fileparts(input_data);
    %choices=[choices fullfile(work_subfolder,[n e ])];
    choices=[choices input_data];
end
% the defacto val is being pased in now so instead of rebuilding, we'll use
% the passed in val
% choices=[choices  fullfile(work_subfolder,[volume_runno,'.fid']) ];

for fidname=choices
    volume_fid=fidname{1};
    fid_info=dir(volume_fid);
    if ~exist(volume_fid,'file') || ~isempty(fid_info) && fid_info.bytes<=60
        fid_transfer_status=0;
    else
        fid_transfer_status=1;
        break;
    end
end
end

function scan_vol_status=check_remote_fid(work_subfolder,volume_runno,the_scanner,input_data,volume_number,bbytes)
scan_vol_ready=0;
%[fid_path.current, local_or_streaming_or_static]=find_fid_path.currentCS(the_scanner.name,runno,agilent_study,scanner_acquisition);
[data_mode,fid_path]=get_data_mode(the_scanner,work_subfolder,input_data);
scan_vol_status.data_mode=data_mode;
scan_vol_status.fid_path=fid_path;
%if (local_or_streaming_or_static == 2)
if strcmp(data_mode,'streaming')
    if exist('bbytes','var')&& bbytes~=0
        %vr_array = strsplit(volume_runno, '_m');
        %volume_number = str2double(vr_array{end}) + 1;
        % ready=check_subvolume_ready_in_fid_quiet(fid_path.current,volume_number,bbytes,the_scanner.name,remote_user);
        % consider using fid_consistency here to ensure we have the tag to
        % load becuaes it'll bomb out if inconsistent.
        vol_tag=fullfile(work_subfolder,sprintf('.%s.fid_tag',volume_runno));
        %%%
        % the_scanner.fid_get_tag(fid_path.current,vol_tag,volume_number,bbytes);
        %%%
        assert(the_scanner.fid_consistency(fid_path.current,vol_tag,0,volume_number,bbytes),'fid inconsistent!');
        %%%
        [~,~,~,~,~,complete_file_size, blk_hdr,full_hdr]=load_fid_hdr(vol_tag);
        ready=blk_hdr.status.hasData;
        %%%
        if ready
           scan_vol_ready=1; 
        end
    end
else
    % data mode is either local OR static(meaning acq done) in both cases
    % that means our acquisition is done. 
    scan_vol_ready=1;
end
scan_vol_status.ready=scan_vol_ready;
end


function resolved_tag=wildcard_tag_finder(tag_pattern)

resolved_tag='__FIND_FLAG_ERROR';

[p,n,e]=fileparts(tag_pattern);
%found=regexpdir(p,[n,e]);
found=wildcardsearch(p,[n e]);

if ~numel(found)
    return; end

newest=dir(found{1});
res(1)=newest;
for n=2:numel(found)
    res(n)=dir(C{1});
    res(n).date
    if  res(n).date < newest.date
        newest=res(n);
    end    
end
resolved_tag=fullfile(p,newest.name);
%{
% older terminal based lookup
[s,tag_pattern]=system(sprintf('ls -t %s|head -n2|tail -n1',tag_pattern));
if s ~= 0
    tag_pattern='__FIND_FLAG_ERROR';
end
resolved_tag=strtrim(tag_pattern);
%}
end
