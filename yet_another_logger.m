function yet_another_logger(log_msg,mode,log_file,error_flag)
% Unnecessary reinvention of a function that can log messages to a log
% file, and also to standard output if 'verbose' is turned on .
%
% 19 September 2017
% Reinventor: BJ Anderson, CIVM
%
% Modes:
% 1) log to log_file and standard output
% 2) log to log_file only
% 3) log to standard output only
%
% Multiple log_files can be specified in a single, comma-delimited string
%
% error_flag will append 'ERROR:' to message if not already present, and
% send to standard error instead of standard output for modes 1 & 3

if ~exist('mode','var')
    mode = 1;
end

if ~exist('log_file','var')
    mode = 3;
else
    log_files = strsplit(log_file,',');
end

if ~sum(1:3==mode)
    mode  = 3;
end


file_descriptor = 1;
if exist('error_flag','var') && error_flag
    if ~strcmp(log_msg(1:5),'ERROR')
        log_msg = ['ERROR: ' log_msg];
    end
    file_descriptor = 2; % 2 send message to standard error instead of standard out.
end

for ff = 1:numel(log_files)
    c_log_file = log_files{ff};
    if (mode == 1) || (mode == 2)
        log_fid = fopen(c_log_file,'a+');
        fprintf(log_fid,'%s',log_msg);
        fclose(log_fid);
    end
end

if mode ~=2
    fprintf(file_descriptor,'%s',log_msg);
end
end

