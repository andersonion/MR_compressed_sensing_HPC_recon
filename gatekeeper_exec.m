function out_code = gatekeeper_exec( local_file,remote_file,scanner,log_file,block_number,bbytes,interval,time_limit)
% function out_code = gatekeeper_exec(local_file, remote_file, scanner, log_file, block_number, bbytes, interval, time_limit)
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
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

if ~isdeployed;

else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end
out_code = 1; % Default is failure.
scanner_user='omega';
most_recent_fid_cmd='ls -tr /home/mrraw/*/*.fid/fid | tail -n1';
remote_most_recent_fid_cmd = sprintf('ssh %s@%s "%s"',scanner_user,scanner,most_recent_fid_cmd);
status = 1;
logged=0;
[status,most_recent_fid] = system(remote_most_recent_fid_cmd);
if status
    error_flag=1;
    log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    % error_due_to_network_issues
    if isdeployed
        quit force
    else 
        return
    end
end

fid_check=0;
if strcmp(remote_file((end-2):end),'fid')
    fid_check=1;
end
if (~exist('block_number','var') && (fid_check == 1))
    local_fid_array = strsplit(local_fid,'_m');
    block_number=str2double(local_fid_array{end})+1;
else
    if ischar(block_number)
        block_number=str2double(block_number);
    end  
end
if ~exist('bbytes','var')
    bbytes= 0; % If no bbytes specified, the first fid blockheader will be checked.
else
    if ischar(bbytes)
        bbytes=str2double(bbytes);
    end
end
if ~exist('interval','var')
    interval = 120; % Default interval of 2 minutes
else
    if ischar(interval)
        interval=str2double(interval);
    end    
end                                                                                                                                                                                                                                                                                                                                                                                     
if ~exist('time_limit','var')
    time_limit=2592000; % Default time_limit of 30 days
else
    if ischar(time_limit)
        time_limit=str2double(time_limit);
    end    
end

%% Begin process of waiting...
ready = 0;
max_checks = ceil(time_limit/interval);
effective_time_limit = ceil(max_checks*interval)/60;
log_msg = sprintf('Gatekeeper will now check every %i seconds (up to %i minutes) for either local file ''%s'' to exist, or its corresponding data to be written on scanner %s.\n',interval,effective_time_limit,local_file,scanner);
log_mode = 1;
yet_another_logger(log_msg,log_mode,log_file);
tic

for tt = 1:max_checks
    if exist(local_file,'file')
        ready = 1;
    else
        remote_size=get_remote_filesize( remote_file,scanner );
        if (remote_size > 0)
            if fid_check
                ready=check_subvolume_ready_in_fid_quiet(remote_file,block_number,bbytes,scanner,scanner_user);
            else
                ready =1;
            end
        end
    end
    if ready 
        break 
    else
        most_recent_fid_cmd='ls -tr /home/mrraw/*/*.fid/fid | tail -n1';
        remote_most_recent_fid_cmd = sprintf('ssh %s@%s "%s"',scanner_user,scanner,most_recent_fid_cmd);        
        status = 1;
        [status,c_most_recent_fid] = system(remote_most_recent_fid_cmd);
        if status
            error_flag=1;
            log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
            yet_another_logger(log_msg,log_mode,log_file,error_flag);
            % error_due_to_network_issues
            if isdeployed
                quit force;
            else
                error(log_msg);
            end
        end
        if ~strcmp(c_most_recent_fid,most_recent_fid)
            wait_time = floor(toc/60);
            error_flag=0;
            log_msg=sprintf('\nThe in-progress scan appears to have completed; data should be available in its static home on the scanner.\n\tAfter waiting %i minutes the following fid was created:\n\t%s\n',wait_time,c_most_recent_fid);
            yet_another_logger(log_msg,log_mode,log_file,error_flag);
            out_code=0; % '2' is reserved for this particular type of failure. --> Not the best error condition.
            if isdeployed
                quit;
            else
                return;
            end
        end
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
    log_msg=sprintf('\nWaiting for the input data for the file ''%s'' was NOT ready after %i minutes of waiting.\n(Expected source file was: ''%s'' on %s);\n\t%s',local_file,wait_time,remote_file,scanner);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    if isdeployed
        quit force;
    else
        error(log_msg);
    end
end
end
