function consistency_status = write_or_compare_fid_tag( ...
    input_fid,fid_tag_path,volume_number,scanner,user)
% busy function handling fid_er_print operations. 
% would be good to refactor into a get_fid_tag, and a compare_fid_tag.
%

original_fid_tag_path = fid_tag_path;
consistency_status = 0;
% This can run locally just as well, though it is designed for remote deployment.
% (when scanner is specified).
local_operation_only=1;

if ~exist('volume_number','var')
    volume_number = 1;
end

fid_tag_path=sprintf('/tmp/%s_%i_%i.fid',datestr(now,30),volume_number,ceil(rand(1)*10000));

%{
% force write on volume_number 1 is bad in case of a moved fid file.
if (volume_number == 1)
    write_mode = 1;
else
    write_mode = 0;
    if ~exist(original_fid_tag_path,'file')
        % in case of error give us 30 seconds and retest.
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
%}
write_mode = 0;
if ~exist(original_fid_tag_path,'file') 
    if volume_number==1
        write_mode = 1;
    else 
        % in case of error give us 30 seconds and retest.
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
    local_operation_only=0;
    fprintf('fid checking remote on: %s',scanner)
    if ~exist('user','var')
        user='omega';
        fprintf(' with default: %s\n',user);
    else
        fprintf(' with: %s\n',user);
    end
    ready=check_subvolume_ready_in_fid_quiet(input_fid,1,1,scanner,user);
else
    ready=check_subvolume_ready_in_fid_quiet(input_fid,1,1);
end

consistency_status = 0;
if ready
    %agilent file headers are always 32 bytes big. + 28 bytes of first block + 40 bytes of block one
    header_size=100;
    
    % command when run remotely (or locally, even) will pull bytes 1-26 and
    % 29-102 of a fid (skipping the two bytes that represent the status of the
    % whole fid, because those will change when the acq is done.
    % This is a near replicate of the work done in check subvolume. Would
    % be good to consolidate that, but that is for later.
    lin_dd_status=' status=noxfer';
    lin_of=[' of=' fid_tag_path];
    lin_append=' oflag=append';
    mac_of='';
    if ismac
        lin_dd_status='';
        lin_of='';
        lin_append='';
        mac_of=['>> ' fid_tag_path];
    end
    dd_cmd =  ['( dd bs=26' lin_dd_status ' count=1' lin_of mac_of...
        ' && dd' lin_dd_status ' bs=2 skip=1 count=0'...
        ' && dd' lin_dd_status ' bs=74 count=1' lin_of ' conv=notrunc' lin_append ' ) < ' input_fid mac_of];
    
    if local_operation_only
        % runs dd command locally
        system(dd_cmd);
    else
        % runs dd command remotely.
        ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);
        % fetches the fid file
        scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,fid_tag_path,fid_tag_path);
        ssh_call(ssh_dd);
        ssh_call(scp_fid);
    end
    
    file_meta=dir(fid_tag_path);%gets metadata, especially file bytes.
    if file_meta.bytes ~= header_size
        error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
    else
        if write_mode
            consistency_status = 1;
            % set NON friendly permisions to file
            % BECAUSE OVERWRITES OF THIS TAG ARE DANGEROUS!
            chmod_cmd=sprintf('chmod 444 %s',fid_tag_path);
            [~,~] = system(chmod_cmd); % set perms
            [~,~] = system(sprintf('mv %s %s',fid_tag_path,original_fid_tag_path));
        else
            diff_cmd = sprintf('diff -q %s %s',original_fid_tag_path,fid_tag_path);
            [s,diff_result] = system(diff_cmd);
            if isempty(diff_result) || s~=0
                consistency_status = 1;
            end
            tmp_rm_cmd = sprintf('rm %s',fid_tag_path);
            [s, tmp_rm_out] = system(tmp_rm_cmd);
        end
        if ~local_operation_only
            % removes temp fid remotely.
            ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,fid_tag_path);
            [s, tmp_rm_out]  = ssh_call(ssh_rm_cmd);
        end
    end
end
end

