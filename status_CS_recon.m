function status_CS_recon(base_runno,varargin)
% function recon_report_progress(rx,biggus_diskus|Write|range|check_scanner|test)
% 
% function to report total progress of a cs recon. 
% Supports several optional args
%   alternate BIGGUS_DISKUS to check other peoples recon progress
%   range will take the next parameter and treat it as a matlab
%         expression (DANGEROUS CODE EVAL) will then check only those
%         working folders.
%   check_scanner normally skips ssh checking, this will use ssh to go ask
%         the scanner the current progress 
%   Write will save an orthocenter to a file in base working folder.
%   test  test orthoo mode telling the output path but not bothering to run
%         the othocenter extraction
% 
% example using all options(except test)
%   stats_CS_recon N12345 range 8:12 Write check_scanner /mnt/alternate_scratch_space
% 
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
if ~exist('base_runno','var')
    error('must supply runno');
end
data_directory=getenv('BIGGUS_DISKUS');
save_ortho_centers=false;
test_mode=false;
check_scanner=0;
if nargin>1
    vu=ones(size(varargin));
    for ai=1:nargin-1
        if exist(varargin{ai},'dir')
            data_directory=varargin{ai};
            vu(ai)=0;
        elseif strcmp(varargin{ai},'Write')
            save_ortho_centers=true;
            vu(ai)=0;
        elseif strcmp(varargin{ai},'test')
            test_mode=true;
            vu(ai)=0;
        elseif strcmp(varargin{ai},'range')
            range=eval(varargin{ai+1});
            vu(ai)=0;
            vu(ai+1)=0;
        elseif strcmp(varargin{ai},'check_scanner')
            check_scanner=1;
            vu(ai)=0;
        end
    end
    if sum(vu)>0
        celldisp(varargin);
        error('Un used input args, only scratch directory, and ''Write'' are supported');
    end
end

% TODO convert this to a matlab only function.
[s,ls_blob]=system(sprintf('ls -d %s/%s.work/%s_m*/',data_directory,base_runno,base_runno)); % the */ forces a trailing slash.
if s==0 % unix status check
    ls_blob=strtrim(ls_blob);
    C=strsplit(ls_blob);
    [~, index] = sort(C);
    % rundata will initally be the directories to check, if we're writing
    % out slices, it will become a 2 part cell with the written image path
    rundata = C(index);clear C index;
    progress=0;
    range_start=1;
    range_end=numel(rundata);
    if exist('range','var')
      range_start=range(1);
      range_end=range(end);
    end
    for ri=range_start:range_end
        if isempty(rundata{ri})
           continue;
        end
        % cut the slash off the path, we know it has the slash on because
        % of how we use ls to get the directory. 
        vd=rundata{ri}(1:end-1);
        [~,vr]=fileparts(vd);
        %  [ starting_point ,log_msg, vol_status, extended] = volume_status( ...
        %    volume_dir,volume_runno,the_scanner,volume_number,input_data,bbytes )
        if ~check_scanner
            % [~,lm,pc]=check_status_of_CSrecon(vd,vr);
            [~,lm,pc]=volume_status(vd,vr);
        else
            %[~,lm,pc]=check_status_of_CSrecon(vd,vr,[],base_runno);
            [~,lm,pc]=volume_status(vd,vr,[],base_runno);
        end
        %  (volume_dir,volume_runno,scanner,base_runno,study,agilent_series,bbytes )
        fprintf('%05.2f%% - %s',pc,lm);
        
        progress=progress+pc;
        % switched pc from 100, to 99.5 so that we'll still ortho send if our procpar is hanging.
        if pc>=99.5 && save_ortho_centers
            %% if we've got a complete volume dump an ortho slice?
            % we may be able to use lower pct, like 98, I forget what pct
            % the scp to final costs.
            % Dont dump it now, just keep track of which ones, we'll parfor
            % the dumps becuase they could be slow. 
            out_orth=fullfile(getenv('BIGGUS_DISKUS'),[base_runno '.work'],[vr '_ortho.png']);
            if ~exist(out_orth,'file') || test_mode
                rundata{ri}={rundata{ri},out_orth};
            end
        end
    end
    % intentionally rounded total_completion down so we wont report 100%
    % until its certain
    total_completion=floor(progress/(numel(rundata)));
    %% remove entries which are either not done, or preivously saved their ortho slices, 
    for ri=numel(rundata):-1:1
        if ~iscell(rundata{ri})
            rundata(ri)=[];
        end
    end
    %% give the global feedback.
    fprintf('TOTAL progress: %05.2f%%\n',total_completion);
    if save_ortho_centers && numel(rundata)>0
        %% actually go run the ortho slices
        fprintf('\t %i new volumes completed, orthoslices saving now... \n',numel(rundata));
        t_save=tic;
        if ~test_mode
            parfor ri=1:numel(rundata)
                if iscell(rundata{ri})
                    fprintf('\tsave start %i',ri);
                    civm_save_ortho(rundata{ri}{1},rundata{ri}{2})
                end
            end
        end
        %% print out which ortho's were saved with clear sigle to watch for (->)
        fprintf('\t save complete in %g seconds\n',toc(t_save));
        for ri=1:numel(rundata)
            if iscell(rundata{ri})
                fprintf('\t-> %s\n',rundata{ri}{2})
            end;
        end
    end
else
    error('didnt find runno work (%s.work) in working folder %s. \nAre you trying to check for someone else? \nPlease specify their working folder.',base_runno,data_directory);
end
