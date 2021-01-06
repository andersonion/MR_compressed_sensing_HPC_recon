function get_hdr_from_fid(input_fid,local_fidpath,scanner,user)
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
local_operation_only=1; % This can run locally just as well, though it is designed for remote deployment (when scanner is specified).
if exist('scanner','var')
    local_operation_only=0;
    
    if ~exist('user','var')
        user='omega';
    end
end
header_size=32; %agilent file headers are always 32 bytes big.
if local_operation_only
    dd_dest_path=local_fidpath;
else
    remote_temp_fidpath=sprintf('/tmp/%s_%s_%i.fid',datestr(now,30),'hdr',ceil(rand(1)*10000));
    dd_dest_path=remote_temp_fidpath;
end
% command when run remotely (or locally, even) will pull out just one block into a fid file
lin_dd_status=' status=noxfer';
if ismac && local_operation_only
    lin_dd_status='';
end
dd_cmd = ['( dd bs='  num2str(header_size) lin_dd_status ' count=1 of=' dd_dest_path ') < ' input_fid ];
if local_operation_only 
    % runs dd command locally
    system(dd_cmd);
else
    % runs dd command remotely.
    ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);
    % fetches the fid file
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,remote_temp_fidpath,local_fidpath);    
    ssh_call(ssh_dd);
    ssh_call(scp_fid);
end
file_meta=dir(local_fidpath);%gets metadata, especially file bytes.
if file_meta.bytes~=header_size
    error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
else
    % sets read only permissions on locacl_fidpath
    chmod_cmd=sprintf('chmod 444 %s',local_fidpath);
    system(chmod_cmd); % set perms
    if ~local_operation_only
        % removes temp fid remotly.
        ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,remote_temp_fidpath);
        system(ssh_rm_cmd);
    end
end
end
