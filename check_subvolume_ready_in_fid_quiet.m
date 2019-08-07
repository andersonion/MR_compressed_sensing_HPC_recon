function [ready, bhdr]=check_subvolume_ready_in_fid_quiet(...
    input_fid, volume_number, bbytes, scanner, user, options)
% [ready,bhdr]=check_subvolume_ready_in_fid(input_fid,volume_number,bbytes,scanner,user,options)
%Verify's a subvolume is ready in the remote fid.
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
opt_s=mat_pipe_option_handler(options,types);
% This can run locally just as well, 
% though it is designed for remote deployment (when scanner is specified).  
local_operation_only=1;
test=opt_s.test;
if test
    local_operation_only=1; 
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
        local_operation_only=0;
        if ~exist('user','var')
            user='omega';
        end
     end
end

header_size=32; %agilent file headers are always 32 bytes big.
block_header=28; %agilent block headers are 28 bytes big. 
% byte_position = header_size+bbytes*(volume_number-1)+4;

% FOR SOME REASON THIS COMMAND IS INCREDIBLY SLOW WHEN RUN AGAINST LOCAL DATA!
% OH I SEE, ITS BECAUSE WE"RE LOOKING AT 1 BYTE BY RUNNING THROUGH EACH
% BYTE OF THE FILE! 
% header_grab = [ 'tail -q -c +' num2str(byte_position) ' ' input_fid ...
%     ' | head -c 1 | xxd -b - | tail -c +17 | head -c 1' ];
% HERE's AN IDEA, JUST GET ALL THE HEADER BYTES, THEN READ THE ONE BYTE :-P
temp_fidpath=sprintf('/tmp/%s_blk%i_%i.fhd',datestr(now,30),volume_number,ceil(rand(1)*10000));
lin_dd_status=' status=noxfer';
lin_of=[' of=' temp_fidpath];
lin_append=' oflag=append';
mac_of='';
if ismac && local_operation_only
    lin_dd_status='';
    lin_of='';
    lin_append='';
    mac_of=['>> ' temp_fidpath];
end
header_grab = ['( dd bs='  num2str(header_size)  lin_dd_status ' count=1' lin_of mac_of ...
    ' && dd ' lin_dd_status ' bs=' num2str(bbytes)  ' skip=' num2str(volume_number-1) ' count=0'...
    ' && dd ' lin_dd_status ' bs=' num2str(block_header) ' count=1' lin_of ' conv=notrunc' lin_append ' ) < ' input_fid mac_of];

if local_operation_only 
    % runs header scrape command locally
    [s, dd_out] = system(header_grab);
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
    % scps minimalist script, and runs it, script removes itself remotely, 
    % this removes local copy
    ssh_grab=sprintf(['scp -pq %s %s@%s:~/ ' ...
        '&& ssh %s@%s "~/%s" '...
        '&& rm %s'],...
        scr_f,user,scanner,...
        user,scanner,scrname,...
        scr_f);
    [s, dd_out]=ssh_call(ssh_grab); %run remotely
    
    % fetches the fid file  to same location locally. 
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,temp_fidpath,temp_fidpath);
    [s, scp_out  ] = system(scp_fid); % fetch fid
end

file_meta=dir(temp_fidpath);%gets metadata, especially file bytes.
if file_meta.bytes ~= header_size+block_header
    warning('Problem with the copy/transfer! temporary file is %s',temp_fidpath);
    ready=0;
    bhdr=struct;
    return
else
    if ~local_operation_only
        % removes temp fid remotly.
        ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,temp_fidpath);
        [s, tmp_rm_out] = system(ssh_rm_cmd);
    end
    % read block header
    bhdr=load_blk_hdr(temp_fidpath,header_size);
    % get the status bit for completion, from BJ's research it is the just
    % one bit for completion.
    ready=bitget(bhdr.status,1);
    % remove local header.
    rm_cmd=sprintf('rm %s',temp_fidpath);
    [s, tmp_rm_out] = system(rm_cmd); % run remove
end

