function [ starting_point ,log_msg] = check_status_of_CSrecon( workdir,volume_runno,scanner,runno,study,series,bbytes )

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

% Required inputs:
%   workdir (volume_subfolder, so '../volume_runno NOT '../volume_runno/work/')
%   volume_runno (usually runno_mXX)

% Required for earlier check calls, if absent when needed, will return
% starting_point = 0:
%   scanner
%   runno
%   study
%   series
%   bbytes (bytes per fid block)

%{
if ~isdeployed
   workdir = '/glusterspace/S67669.work/S67669_m12/'; 
   volume_runno = 'S67669_m12';
   log_file = '/glusterspace/S67669.work/S67669_m12.recon_log';
end
%}

%
starting_point = 6;

% Check for recon flag
volume_flag = [workdir '/.' volume_runno '.recon_completed'];

if ~exist(volume_flag,'file')
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
            system(['mkdir -m 775 ' work_subfolder]);
        end
        
        temp_file = [work_subfolder '/' volume_runno '.tmp'];
        
        move_up_a_stage =0;
        if exist(temp_file,'file')
            [slices_remaining,~,~] = read_header_of_CStmp_file(temp_file);  % Need to remember that we are going to add the headersize as the first bytes
        else
            slices_remaining = 1; % Will not bother to determine the exact number here.
            move_up_a_stage = 1;
        end
        
        if (slices_remaining)
            starting_point = 3;
            
            % Check for a complete workspace file
            workspace_file = [work_subfolder '/' volume_runno '_workspace.mat'];
            
            try
                %dummy = load(workspace_file,'aux_param.maskSize'); % Need to try to load an arbitrary variable from the work file
                dummy_mf = matfile(workspace_file,'Writable',false);
                tmp_param = dummy_mf.param;
                
            catch
               move_up_a_stage = 1;
            end
            
            
            if (move_up_a_stage)
                starting_point = 2;
                % Check to see if the volume fid is ready.
                volume_fid = [work_subfolder '/' volume_runno '.fid'];
                
                if ~exist(volume_fid,'file')
                    starting_point = 1;
                    
                    % Need to remember to  handle differently for single
                    % blocks scans...I think (I haven't put in the split code for this yet!).
                    
                    if (exist('scanner','var') && exist('runno','var') && exist('study','var') && exist('series','var'))
                        [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,series);
                        
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

log_msg =sprintf('Starting point for volume %s: Stage %i.\n',volume_runno,starting_point);



end

