function puller_glusterspaceCS_2(runno,datapath,scanner,workpath,mode,overwrite)
% puller_glusterspaceCS_2(runno,datapath,scanner,workpath,mode,overwrite)
% mode: 1 -> pull fid, 2 -> pull procpar, 3 -> pull both.
% This function name is terrible, and only marginally connects to its
% purpose. -James 20171204
%check arguments
if nargin<5
    error('not enough input arguments');
elseif nargin==5
    overwrite=0;
elseif nargin~=6
    error('too many input arguments arguments');
end
%create work directory and handle overwrite option
if exist(workpath,'dir') && overwrite==1
    display('data already exists in workpath and you have specified to overwrite existing data');
    system(['rm -r ' workpath]);
    mkdir(workpath);
elseif ~exist(workpath,'dir')
    mkdir(workpath);
end
fid_pull_cmd=['scp omega@' scanner ':' datapath '/fid ' workpath '/' runno '.fid'];
procpar_pull_cmd=['scp omega@' scanner ':' datapath '/procpar ' workpath '/' runno '.procpar'];
%pull the fid file and the procpar to the work directory if they dont exist
%if they do exist check filesize
if (mode == 1) || (mode == 3)
    if ~exist([workpath '/' runno '.fid'],'file')
        %system(fid_pull_cmd);
        status = 1;
        logged=0;
        [status,~] = system(fid_pull_cmd);
        if status
            %error_flag=1;
            log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\ncmd = %s\n',scanner,fid_pull_cmd);
            disp(log_msg)
            %yet_another_logger(log_msg,log_mode,log_file,error_flag);
            error_due_to_network_issues
            %quit
        end
    end
end
if (mode == 2) || (mode == 3)
    if ~exist([workpath '/' runno '.procpar'],'file')
        %system(procpar_pull_cmd);
        status = 1;
        logged=0;
        [status,~] = system(procpar_pull_cmd);
        if status
            %error_flag=1;
            log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\ncmd = %s\n',scanner,procpar_pull_cmd);
            disp(log_msg)
            %yet_another_logger(log_msg,log_mode,log_file,error_flag);
            error_due_to_network_issues
            %quit
        end
    end
end
