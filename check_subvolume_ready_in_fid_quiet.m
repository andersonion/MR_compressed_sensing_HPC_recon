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
    % Remote run routinely fails!, probably due to the compilcated nature
    % of stringing 5 commands together. 
    % Easiest solution is to dump that to a script, send the script, and
    % run the script remotely. 
    % On more complete investigation, it could be that node network
    % disconnect issue frustrated this code.
    scrname=sprintf('get_vol_%i_status.sh',volume_number);
    scr_f=fullfile('/tmp',scrname);
    %% scp and run
    fileID = fopen(scr_f,'w');
    if fileID == -1
        log_msg=sprintf('Failure to open /tmp script %s for writing',scr_f);
        disp(log_msg)
        error_due_to_network_issues
    end
    fprintf(fileID, '#!/bin/bash\n');
    fprintf(fileID, '%s\n',header_grab);
    fprintf(fileID, 'rm $0');% WARNING.... This will remove the script on run. Might be bad idea.
    fclose(fileID);
    system(sprintf('chmod u+x %s',scr_f));
    % runs header scrape command remotely.
    % ssh_grab=sprintf('ssh %s@%s "%s"',user,scanner,header_grab);
    % scps minimalist script, and runs it, removes local copy
    ssh_grab=sprintf(['scp -q %s %s@%s:~/ ' ...
        '&& ssh %s@%s "~/%s" '...
        '&& rm %s'],...
        scr_f,user,scanner,...
        user,scanner,scrname,...
        scr_f);
    [~,ready_1]=ssh_call(ssh_grab); %run remotely
end
ready_1=str2num(ready_1(1)); % was str2double, but str2num does a better job failing when given text.
%if isnumeric(ready_1)
if ~isempty(ready_1)
    ready= ready_1;
else
    ready = 0; % An error condition is indistinguishable from it not being ready...
end

end

