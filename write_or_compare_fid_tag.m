function consistency_status = write_or_compare_fid_tag(input_fid,fid_tag_path,volume_number,scanner,user)
% busy function handling fid_er_print operations. 
% would be good to refactor into a get_fid_tag, and a compare_fid_tag.
%

original_fid_tag_path = fid_tag_path;
consistency_status = 0;
for_locals_only=1; % This can run locally just as well, though it is designed for remote deployment (when scanner is specified).

if ~exist('volume_number','var')
    volume_number = 1;
end

if (volume_number == 1)
    write_mode = 1;
else
    write_mode = 0;
    fid_tag_path=sprintf('/tmp/%s_%i_%i.fid',datestr(now,30),volume_number,ceil(rand(1)*10000));
    if ~exist(original_fid_tag_path,'file')
        pause(30)
        if ~exist(original_fid_tag_path,'file')
            log_mode = 3;
            error_flag = 1;
            log_msg =sprintf('Original fid_tag path (''%s'') does not exist. Dying now.\n',original_fid_tag_path);
            yet_another_logger(log_msg,log_mode,'',error_flag);
            quit force
        end
    end
end

if exist('scanner','var')
    for_locals_only=0;
    if ~exist('user','var')
        user='omega';
    end
    ready=check_subvolume_ready_in_fid_quiet(input_fid,1,1,scanner,user);
else
    ready=check_subvolume_ready_in_fid_quiet(input_fid,1,1);
end

if ready
    header_size=100; %agilent file headers are always 32 bytes big. + 28 bytes of first block + 40 bytes of block one
    if for_locals_only
        dd_dest_path=fid_tag_path;
    else
        remote_temp_fidpath=sprintf('/tmp/%s_%i_%i.fid',datestr(now,30),volume_number,ceil(rand(1)*10000));
        dd_dest_path=remote_temp_fidpath;
    end
    
    % command when run remotely (or locally, even) will pull bytes 1-26 and
    % 29-102 of a fid (skipping the two bytes that represent the status of the
    % whole fid, because those will change when the acq is done.
    dd_cmd =  ['( dd bs=26 status=noxfer count=1 of=' dd_dest_path ...
        ' && dd status=noxfer bs=2 skip=1 count=0'...
        ' && dd status=noxfer bs=74 count=1 of=' dd_dest_path ' conv=notrunc oflag=append ) < ' input_fid ];
    
    if for_locals_only
        % runs dd command locally
        system(dd_cmd);
    else
        % runs dd command remotely.
        ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);
        % fetches the fid file
        scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,remote_temp_fidpath,fid_tag_path);
        %{
        system(ssh_dd); %run remote dd
        system(scp_fid); % fetch fid
        %}
        ssh_call(ssh_dd);
        ssh_call(scp_fid);
    end
    
    file_meta=dir(fid_tag_path);%gets metadata, especially file bytes.
    if file_meta.bytes ~= 100
        consistency_status = 0;
        error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
    else
        if write_mode
            consistency_status = 1;
            % sets okay permisions to file, u+g=rw, o=r
            chmod_cmd=sprintf('chmod 664 %s',fid_tag_path);
            system(chmod_cmd); % set perms
        else
            diff_cmd = sprintf('diff -q %s %s',original_fid_tag_path,fid_tag_path);
            [~,results] = system(diff_cmd);
            if isempty(results)
                consistency_status = 1;
            else
                consistency_status = 0;
            end
            tmp_rm_cmd = sprintf('rm %s',fid_tag_path);
            system(tmp_rm_cmd);
        end
        if ~for_locals_only
            % removes temp fid remotely.
            ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,remote_temp_fidpath);
            %{
            system(ssh_rm_cmd);
            %}
            ssh_call(ssh_rm_cmd);
        end
    end
else    
    consistency_status = 0;
end
end

