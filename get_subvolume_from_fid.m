function get_subvolume_from_fid(input_fid,local_fidpath,volume_number,bbytes,scanner,user)

local_operation_only=1; % This can run locally just as well, though it is designed for remote deployment (when scanner is specified).
test=0;
if test
    if ~exist('scanner','var')
     scanner='kamy';
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
if local_operation_only
    dd_dest_path=local_fidpath;
else
    f_time = datestr(now,30);
    c_time = datestr(now,'FFF');
    rand_vector = ceil(rand(str2num(c_time)+1,1)*10000);
    r_num = rand_vector(min(volume_number,numel(rand_vector)));

    remote_temp_fidpath=sprintf('/tmp/%s_%i_%04i.fid',f_time,volume_number,r_num);
    dd_dest_path=remote_temp_fidpath;
end

% command when run remotely (or locally, even) will pull out just one block into a fid file
lin_dd_status=' status=noxfer';
lin_of=[' of=' dd_dest_path];
lin_append=' oflag=append';
mac_of='';
if ismac 
    lin_dd_status='';
    lin_of='';
    lin_append='';
    mac_of=['>> ' dd_dest_path];
end
dd_cmd = ['( dd bs='  num2str(header_size) lin_dd_status ' count=1' lin_of mac_of ...
    ' && dd ' lin_dd_status ' bs=' num2str(bbytes)  ' skip=' num2str(volume_number-1) ' count=0'...
    ' && dd ' lin_dd_status ' bs=' num2str(bbytes)  ' count=1' lin_of ' conv=notrunc' lin_append  ' ) < ' input_fid mac_of];

if local_operation_only 
    % runs dd command locally
    [~,~] = system(dd_cmd);
else
    % runs dd command remotely.
    % first cleans old files we may have left on system
    % (older than 120 min)
    pre_clean_cmd = 'find /tmp/ -maxdepth 1 -mmin +120 -iregex ".*\.fid" -exec rm {} \;';
    ssh_pre_clean=sprintf('ssh %s@%s "%s"',user,scanner,pre_clean_cmd);  
    [~,~] = system(ssh_pre_clean);
    % ssh_call(ssh_pre_clean);% cant use ssh_call, because it fails when we
    % have a return status, and we have one when find doesnt get any
    % result. Its not clear if ssh_call should be enhanced, or a "real"
    % solution found. 
    
    ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);
    % fetches the fid file
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,remote_temp_fidpath,local_fidpath);
    [~,~] = ssh_call(ssh_dd);
    [~,~] = ssh_call(scp_fid);
end

file_meta=dir(local_fidpath);%gets metadata, especially file bytes.
if file_meta.bytes ~= bbytes+header_size
    error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
else
    % file permissions forced to friendly, u+g=rw, o=r
    chmod_cmd=sprintf('chmod 664 %s',local_fidpath);
    [~,~] = system(chmod_cmd); % set perms
    if ~local_operation_only
        % removes temp fid remotly.
        ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,remote_temp_fidpath);
        disp(ssh_rm_cmd)
        [~,~] = system(ssh_rm_cmd);
    end
end

end

