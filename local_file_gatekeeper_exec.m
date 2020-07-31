function out_code = local_file_gatekeeper_exec( local_file, log_file, interval, time_limit)
% Mainly for checking to see if the needed data has been written to the
% fid, but can be used for procpars and other remote files.
% 
%   
% Written by BJ Anderson, CIVM
% 19 September 2017
%
% If remote file is fid, will read its block header to see if data has been
% written yet.
%
% If a new scan appears and does not match this scan, then it will stop
% waiting.  This should help catch cancelled jobs.

if ~isdeployed;
else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end

%% set defaults
out_code = 1; % Default is failure.
if ~exist('interval','var')
    % Default interval of 2 minutes
    interval = 120;
else
    if ischar(interval)
        interval=str2double(interval);
    end    
end
                                                                                                                                                                                                                                                                                                                                                                                        
if ~exist('time_limit','var')
    % Default time_limit of 30 days
    time_limit=2592000;
else
    if ischar(time_limit)
        time_limit=str2double(time_limit);
    end    
end


%% Begin process of waiting...
ready = 0;
max_checks = ceil(time_limit/interval);
effective_time_limit = ceil(max_checks*interval)/60;

log_msg = sprintf('Gatekeeper will now check every %i seconds (up to %i minutes) for local file(s) ''%s'' to exist.\n',interval,effective_time_limit,local_file);
log_mode = 1;
yet_another_logger(log_msg,log_mode,log_file);

tic
local_files = strsplit(local_file,':');
for tt = 1:max_checks
    c=0;
    for fn=1:numel(local_files)
      if exist(local_files{fn},'file')
          c=c+1;
      end
    end
    if c==numel(local_files)
        ready = 1;   
        break 
    else
        pause(interval);
    end
end
wait_time = floor(toc/60);

if ready
   out_code=0;
   log_msg=sprintf('\nThe data for the file ''%s'' was ready after a %i minute wait time.\n',local_file,wait_time);
   yet_another_logger(log_msg,log_mode,log_file);
else
    error_flag=1;
    log_msg=sprintf('\nWaiting for the input data for the file ''%s'' was NOT ready after %i minutes of waiting.\n',local_file,wait_time);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    if isdeployed
        quit force;
    else
        error(log_msg);
    end
end

end

