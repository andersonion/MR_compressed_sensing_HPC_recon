function [ready,bhdr]=check_subvolume_ready_in_fid(input_fid,volume_number,bbytes,scanner,user,options)
% [ready,bhdr]=check_subvolume_ready_in_fid(input_fid,volume_number,bbytes,scanner,user,options)
%Verify's a subvolume is ready in the remote fid. 
warning('MULTI CODE PATH MADNESS! WHAT!');
pause(10);
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
% There is a possiblity that there is more than one header. But for now we're ignoring that. 
% That should be checked when we load the fid header and an error thrown
% when it occurs.

temp_fidpath=sprintf('/tmp/%s_blk%i_%i.fhd',datestr(now,30),volume_number,ceil(rand(1)*10000));

% skip=header_size+((volume_number-1)*bbytes)+1;
% HA doesnt even run locall... gotta go back to dd.
% header_grab=sprintf('(tail -c+%i %s| head -c %i > %s)',skip, input_fid , block_header, local_fidpath);

header_grab = ['( dd bs='  num2str(header_size) ' status=noxfer count=1 of=' temp_fidpath ...
    ' && dd status=noxfer bs=' num2str(bbytes)  ' skip=' num2str(volume_number-1) ' count=0'...
    ' && dd status=noxfer bs=' num2str(block_header) ' count=1 of=' temp_fidpath ' conv=notrunc oflag=append ) < ' input_fid ];

if local_operation_only 
    % runs header scrape command locally
    [s, dd_out] = system(header_grab);
else
    % runs header scrape command remotely.
    ssh_grab=sprintf('ssh %s@%s "%s"',user,scanner,header_grab);
    [s, dd_out] = system(ssh_grab); %run remote dd

    % fetches the fid file  to same location locally. 
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,temp_fidpath,temp_fidpath);
    [s, scp_out] = system(scp_fid); % fetch fid
    
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

