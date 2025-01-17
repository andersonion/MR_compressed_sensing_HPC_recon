function [ starting_point ,log_msg,vol_status] = check_status_of_CSrecon( ...
    volume_dir,volume_runno,scanner,runno,agilent_study,agilent_series,bbytes )
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

%{
if ~isdeployed
   workdir = '/glusterspace/S67669.work/S67669_m12/';
   volume_runno = 'S67669_m12';
   log_file = '/glusterspace/S67669.work/S67669_m12.recon_log';
end
%}
starting_point = 6;

% Check for archive_ready sent flag. Previously checked for
% recon_completed, but that has since been changed.
% vflag_name = sprintf('.%s.recon_completed',volume_runno);
% archive_ready_flag = fullfile(volume_dir,vflag_name);
send_archive_tag = fullfile(volume_dir,sprintf('%simages',volume_runno), ...
    sprintf('.%s_send_archive_tag_to_*_SUCCESSFUL',volume_runno));

send_archive_tag=wildcard_tag_finder(send_archive_tag);

headfile_complete=0;
headfile=fullfile(volume_dir,sprintf('%simages',volume_runno), ...
    sprintf('%s.headfile',volume_runno));
if exist(headfile,'file')
    BytesPerKiB=2^10;
    hf_minKiB=20;
    hfinfo=dir(headfile);
    if hfinfo.bytes>hf_minKiB*BytesPerKiB
        headfile_complete=1;
    end
end

vol_status=100;% starting at complete, keep working it down. 
% vol status is what % from 0-100 are we. 
% have to assign each stage some % it takes. lets pretend that only slices matter, and they take 90% of the work.
if ~exist(send_archive_tag,'file') || ~headfile_complete
    % this 2 pct represents processing the procpar, and images and headfile
    % to dest engine. We could break this down further, but its probably
    % not worth it. eg, 1.8% is send data, 0.1% is proces procpar, 0.1% is
    % send procpar.
    % Check for output images
    starting_point = 5;
    vol_status=vol_status-0.1;% this represents the last flag to send.
    send_images=fullfile(volume_dir,sprintf('%simages',volume_runno), ...
        sprintf('.%s_send_images_to_*_SUCCESSFUL',volume_runno));
    send_images=wildcard_tag_finder(send_images);
    if ~exist(send_images,'file')
        vol_status=vol_status-1.8;
    end
    %send_headfile='FILLMEINTWO';.T00020_m0_send_headfile_to_delos_SUCCESSFUL
    send_headfile=fullfile(volume_dir,sprintf('%simages',volume_runno), ...
        sprintf('.%s_send_headfile_to_*_SUCCESSFUL',volume_runno));
    send_headfile=wildcard_tag_finder(send_headfile);
    if ~exist(send_headfile,'file')
        vol_status=vol_status-0.1;
    end
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
    if (finished_slices_count == 0) || (~headfile_exists) % We assume that all the raw files were written at once, and correctly so.
        starting_point = 4;
        vol_status=vol_status-3;
        % Check .tmp file to see if all slices have reconned.
        work_subfolder = fullfile(volume_dir, 'work');
        temp_file = fullfile(work_subfolder, [ volume_runno '.tmp']);
        % the amount of slices remaining as a fraction
        slice_remain_frac= 1;
        move_down_a_stage = 1;
        % This might be acceptable to search for inside the volume_dir
        % instead of hardcoding to some format.
        % Future thought...
        setup_file = fullfile(volume_dir, [ volume_runno '_setup_variables.mat']);
        %{
        % BJ says: 27 Aug 2018, setup_file is not backward compatible, will
        % check to see if it exists and if it doesn't, will look in the
        % point it to the work directory (old behavior); also, James I told
        % you exactly this would be the problem.  Neener neener neener.      
        if ~exist(setup_file,'file')
            setup_file = fullfile(volume_dir, 'work', [ volume_runno '_setup_variables.mat' ]);
        end
        %}
        if exist(temp_file,'file') ...
                && exist(setup_file,'file')
            % Need to remember that we are going to add the headersize as the first bytes
            [~,~,tmp_header] = read_header_of_CStmp_file(temp_file);
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
            %[s,o]=system(sprintf('ls %s',recon_file));o=strtrim(o);
            %if s==0
            if exist(recon_file,'file')
                % if system comand sucessful.
                %recon_file=o;
                rf=matfile(recon_file);
                options=rf.options;
                slices_remaining = length(find(tmp_header<options.Itnlim));
                slice_remain_frac=slices_remaining/numel(tmp_header);
                move_down_a_stage = 0;
            else
                error('couldnt find recon file');
            end
        end
        if ~exist('recon_file','var') && exist('runno','var') && ~exist('agilent_study','var')
            recon_file = fullfile(volume_dir, '..',[ runno '_recon.mat']);
            rf=matfile(recon_file);
            %options=rf.options;
            agilent_series=rf.agilent_series;
            agilent_study=rf.agilent_study;
            scanner=rf.scanner;
            bbytes=rf.bbytes;
            %rf.scanner_name
        end
        % the 90 is so slices only account for 90%
        vol_status=vol_status-90*slice_remain_frac;
        
        if (slice_remain_frac>0.00)
            starting_point = 3;
            % Check for a complete workspace file
            workspace_file = fullfile(work_subfolder,[volume_runno,'_workspace.mat']);
            try
                %dummy = load(workspace_file,'aux_param.maskSize'); % Need to try to load an arbitrary variable from the work file
                % Why doesnt an exist check work here?
                % How about a var listing using 
                %   whos('-file',workspace_file)
                varinfo=whos('-file',workspace_file);
                %dummy_mf = matfile(workspace_file,'Writable',false);
                %tmp_param = dummy_mf.param;
            catch
            end
            if ~exist('varinfo','var') ...
                    || ( ~ismember('imag_data',{varinfo.name}) ...
                    || ~ismember('real_data',{varinfo.name}) )
                %~ismember('volume_scale',{varinfo.name})
                move_down_a_stage = 1;
            end
                        
            if (move_down_a_stage)
                starting_point = 2;
                % Check to see if the volume fid is ready.
                volume_fid=fullfile(work_subfolder,[volume_runno,'.fid']);
                fid_info=dir(volume_fid);
                if ~exist(volume_fid,'file') || ~isempty(fid_info) && fid_info.bytes<=60
                    starting_point = 1;
                    vol_status=vol_status-4;
                    % Need to remember to  handle differently for single
                    % blocks scans...I think (I haven't put in the split code for this yet!).
                    if (exist('scanner','var') && exist('runno','var') && exist('agilent_study','var') && exist('agilent_series','var'))
                        [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,agilent_study,agilent_series);
                        if (local_or_streaming_or_static == 2)
                            remote_user='omega';
                            if exist('bbytes','var')
                                vr_array = strsplit(volume_runno, '_m');
                                volume_number = str2num(vr_array{end}) + 1;
                                ready=check_subvolume_ready_in_fid_quiet(input_fid,volume_number,bbytes,scanner,remote_user);
                                if ~ready
                                    starting_point = 0;
                                end
                            else
                                starting_point = 0;
                            end
                        end
                    else
                        starting_point=0;
                    end
                end
            end
        end
    end
end
if starting_point==0
    vol_status=vol_status-1;
end
status_codes={...
    'Acquistion in progress on scanner.'
    'Extract fid.'
    'Run volume setup. (create workspace.mat and .tmp files)'
    'Slice jobs.'
    'volume cleanup.'
    'Send volume to workstation and write recon_completed flag.'
    'All work done; do nothing.'
    };
% vol_status=sprintf('%s',status_codes{starting_point+1},vol_status);
log_msg =sprintf('Starting point for volume %s: Stage %i. %s\n',volume_runno,starting_point,status_codes{starting_point+1});



end

function resolved_tag=wildcard_tag_finder(tag_pattern)
[s,tag_pattern]=system(sprintf('ls -t %s|head -n2|tail -n1',tag_pattern));
if s ~= 0
    tag_pattern='__FIND_FLAG_ERROR';
end
resolved_tag=strtrim(tag_pattern);
end
