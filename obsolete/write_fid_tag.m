function write_fid_tag(input_fid,local_fidpath,scanner,user)
exit;
local_operation_only=1; % This can run locally just as well, though it is designed for remote deployment (when scanner is specified).


if exist('scanner','var')
    local_operation_only=0;
    
    if ~exist('user','var')
        user='omega';
    end
end


header_size=100; %agilent file headers are always 32 bytes big. + 28 bytes of first block + 40 bytes of block one

if local_operation_only
    dd_dest_path=local_fidpath;
else
    remote_temp_fidpath=sprintf('/tmp/%s_%i_%i.fid',datestr(now,30),volume_number,ceil(rand(1)*10000));
    dd_dest_path=remote_temp_fidpath;
end

% command when run remotely (or locally, even) will pull out just one block into a fid file
dd_cmd = ['( dd bs='  num2str(header_size) ' status=noxfer count=1 of=' dd_dest_path ...
    ') < ' input_fid ];


if local_operation_only 
    % runs dd command locally
    system(dd_cmd);
else
    % runs dd command remotely.
    ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);

    % fetches the fid file
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,remote_temp_fidpath,local_fidpath);

    system(ssh_dd); %run remote dd
    system(scp_fid); % fetch fid
end

file_meta=dir(local_fidpath);%gets metadata, especially file bytes.
if file_meta.bytes ~= header_size
    
    error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
    
else
    
    % sets useful permisions to file, u+g=rw, o=r
    chmod_cmd=sprintf('chmod 664 %s',local_fidpath);
    system(chmod_cmd); % set perms
    
    if ~local_operation_only
        % removes temp fid remotly.
        ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,remote_temp_fidpath);
        
        system(ssh_rm_cmd);
    end
end

end

