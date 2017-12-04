function [ready]=check_subvolume_ready_in_fid_quiet(input_fid,volume_number,bbytes,scanner,user,options)
% [ready,bhdr]=check_subvolume_ready_in_fid(input_fid,volume_number,bbytes,scanner,user,options)
%Verify's a subvolume is ready in the remote fid.
for_locals_only=1;

types.standard_options={
    'test', ' Are we testing code, will read a local fid to check.'
    };
types.beta_options={
    };
types.planned_options={
    };
if ~exist('options','var')
    options={};
end
% if isstruct(options)
% options=mat_pipe_opt2cell(options);
% ends
opt_s=mat_pipe_option_handler(options,types);

test=opt_s.test;
if test
    for_locals_only=1; % This can run locally just as well, though it is designed for remote deployment (when scanner is specified).
    if ~exist('scanner','var')
        scanner_name='kamy';
        aa=load_scanner_dependency(scanner_name);
        scanner=aa.scanner_host_name;   
    end

    if ~exist('user','var')
        user='omega';
    end
else    
     if exist('scanner','var')
        for_locals_only=0;
        
        if ~exist('user','var')
            user='omega';
        end
     end
end


header_size=32; %agilent file headers are always 32 bytes big.

byte_position = header_size+bbytes*(volume_number-1)+4;
header_grab = [ 'tail -q -c +' num2str(byte_position) ' ' input_fid ' | head -c 1 | xxd -b - | tail -c +17 | head -c 1' ];

if for_locals_only 
    % runs header scrape command locally
    [~,ready_1] = system(header_grab);
else
    % runs header scrape command remotely.
    ssh_grab=sprintf('ssh %s@%s "%s"',user,scanner,header_grab);
    [status,ready_1]=system(ssh_grab); %run remotely
    logged=0;
    %{
    for tt = 2:5
        if status
            [status,ready_1]=system(ssh_grab); %run remotely
        else
            if ~logged
                if tt > 1
                    log_msg = sprintf('NOTE: Potential network issues encountered: it has taken %i tries to get a successful response from %s.\n',tt,scanner);
                    %log_mode = 1;
                    %yet_another_logger(log_msg,log_mode,log_file);
                    disp(log_msg);
                end
                logged=1;
            end
        end
    end
    
    if status
        %error_flag=1;
        log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
        %yet_another_logger(log_msg,log_mode,log_file,error_flag);
        disp(log_msg)
        error_due_to_network_issues
        %quit
    end
    %}
end

%ready_1=str2double(ready_1(1));
ready_1=str2num(ready_1(1));

%if isnumeric(ready_1)
if ~isempty(ready_1)
    ready= ready_1;
else
    ready = 0; % An error condition is indistinguishable from it not being ready...
end

end

