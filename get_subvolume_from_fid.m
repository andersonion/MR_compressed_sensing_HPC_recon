function get_subvolume_from_fid(input_fid,local_fidpath,volume_number,bbytes,scanner,user)

for_locals_only=1; % This can run locally just as well, though it is designed for remote deployment (when scanner is specified).
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
        for_locals_only=0;
        if ~exist('user','var')
            user='omega';
        end
     end
end
header_size=32; %agilent file headers are always 32 bytes big.
if for_locals_only
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
dd_cmd = ['( dd bs='  num2str(header_size) ' status=noxfer count=1 of=' dd_dest_path ...
    ' && dd status=noxfer bs=' num2str(bbytes)  ' skip=' num2str(volume_number-1) ' count=0'...
    ' && dd status=noxfer bs=' num2str(bbytes)  ' count=1 of=' dd_dest_path ' conv=notrunc oflag=append ) < ' input_fid ];

if for_locals_only 
    % runs dd command locally
    system(dd_cmd);
else
    % runs dd command remotely.
    % first cleans old files we may have left on system
    % (older than 120 min)
    pre_clean_cmd = 'find /tmp/ -maxdepth 1 -mmin +120 -iregex ".*\.fid" -exec rm {} \;';
    ssh_pre_clean=sprintf('ssh %s@%s "%s"',user,scanner,pre_clean_cmd);  
    system(ssh_pre_clean);
    % ssh_call(ssh_pre_clean);% cant use ssh_call, because it fails when we
    % have a return stauts, and we have one when find doesnt get any
    % result. Its not clear if ssh_call should be enhanced, or a "real"
    % solution found. 
    
    ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);
    % fetches the fid file
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,remote_temp_fidpath,local_fidpath);
    % [status,~]=system(ssh_dd);
    ssh_call(ssh_dd);
    %[status,~]=system(scp_fid);
    ssh_call(scp_fid);
end

file_meta=dir(local_fidpath);%gets metadata, especially file bytes.
if file_meta.bytes ~= bbytes+header_size
    error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
else
    % sets useful permisions to file, u+g=rw, o=r
    chmod_cmd=sprintf('chmod 664 %s',local_fidpath);
    system(chmod_cmd); % set perms
    if ~for_locals_only
        % removes temp fid remotly.
        ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,remote_temp_fidpath);
        disp(ssh_rm_cmd)
        system(ssh_rm_cmd);
    end
end

end

