function out_code = gatekeeper_exec( local_file,remote_file,scanner,log_file,block_number,bbytes,interval,time_limit)
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
    %{
local_file = '/glusterspace/S67665_70.work/S67665_70_m04.fid';
remote_file= '/home/vnmr1/vnmrsys/exp2/acqfil/fid'; 
scanner='kamy';
log_file='/glusterspace/S67665_70.work/S67665_70.recon_log'
block_number='12';
bbytes='52428828'; 
interval='5';
    %}
end
out_code = 1; % Default is failure.
user='omega';
most_recent_fid_cmd='ls -tr /home/mrraw/*/*.fid/fid | tail -n1';
remote_most_recent_fid_cmd = sprintf('ssh %s@%s "%s"',user,scanner,most_recent_fid_cmd);
status = 1;
logged=0;
[status,most_recent_fid] = system(remote_most_recent_fid_cmd);
if status
    error_flag=1;
    log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    error_due_to_network_issues
    %quit
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
%{
initial_elapsed_string = '0 minutes';
log_msg = sprintf('Elapsed time: %s',initial_elapsed_string);
yet_another_logger(log_msg,log_mode,log_file);
%}
for tt = 1:max_checks
    if exist(local_file,'file')
        ready = 1;
    else
        remote_size=get_remote_filesize( remote_file,scanner );
        if (remote_size > 0)
            if fid_check
                ready=check_subvolume_ready_in_fid_quiet(remote_file,block_number,bbytes,scanner,user);
            else
                ready =1;
            end
        end
    end
    if ready 
        break 
    else
        most_recent_fid_cmd='ls -tr /home/mrraw/*/*.fid/fid | tail -n1';
        remote_most_recent_fid_cmd = sprintf('ssh %s@%s "%s"',user,scanner,most_recent_fid_cmd);        
        status = 1;
        [status,c_most_recent_fid] = system(remote_most_recent_fid_cmd);
        if status
            error_flag=1;
            log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
            yet_another_logger(log_msg,log_mode,log_file,error_flag);
            error_due_to_network_issues
            %quit
        end
        if ~strcmp(c_most_recent_fid,most_recent_fid)
            wait_time = floor(toc/60);
            error_flag=0;
            log_msg=sprintf('\nThe in-progress scan appears to have completed; data should be available in its static home on the scanner.\n\tAfter waiting %i minutes the following fid was created:\n\t%s\n',wait_time,c_most_recent_fid);
            yet_another_logger(log_msg,log_mode,log_file,error_flag);
            out_code=0; % '2' is reserved for this particular type of failure. --> Not the best error condition.
            quit
        end
        pause(interval);
    end
    %{
    current_elapsed_time = round(interval*tt/6)/10;
    if (interval*tt/60 < 60)
        current_elapsed_string = sprintf('%.1f minutes',current_elapsed_time);
    else
        current_elapsed_string = sprintf('%.0f minutes',current_elapsed_time);
    end
    log_msg = sprintf('%s',current_elapsed_string); 
    yet_another_logger(log_msg,log_mode,log_file);
    %}
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
    status=this_undefined_variable_will_return_a_goddamn_error_code;
end
end
