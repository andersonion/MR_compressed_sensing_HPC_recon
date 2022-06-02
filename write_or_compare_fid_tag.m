function [ consistency_status, fhd, bhd ] = write_or_compare_fid_tag( ...
    input_fid,fid_tag_path,volume_number,scanner,user)
% busy function handling fid_er_print operations. 
% would be good to refactor into a get_fid_tag, and a compare_fid_tag.
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

% This can run locally just as well, though it is designed for remote deployment.
% (when scanner is specified).
local_operation_only=1;
if exist('scanner','var')
    local_operation_only=0;
    fprintf('fid checking remote on: %s',scanner)
    if ~exist('user','var')
        user='omega';
        fprintf(' with default: %s\n',user);
    else
        fprintf(' with: %s\n',user);
    end
end

if ~exist('volume_number','var')
    volume_number = 1;
end

write_mode = 0;
if ~exist(fid_tag_path,'file') 
    if volume_number==1
        write_mode = 1;
    else 
        % used togive us 30 seconds and retest in case of error.
        % But i want to fail quickly. 
        % pause(30);
        % if ~exist(fid_tag_path,'file')
        log_mode = 3;
        error_flag = 1;
        log_msg =sprintf('Original fid_tag path (''%s'') does not exist. Dying now.\n',fid_tag_path);
        yet_another_logger(log_msg,log_mode,'',error_flag);
        quit(1,'force')
        % end
    end
end

consistency_status = 0;

if ~write_mode
    [fhd.npoints, fhd.nblocks, fhd.ntraces, fhd.bitdepth, ...
        fhd.bbytes, fhd.complete_file_size, ...
        bhd] = load_fid_hdr(fid_tag_path);
    % blk_hdr.status 
    %ready=bitget(bhd.status,1);
    ready=bhd.status.hasData;
    if ~ready
        error('You started recon so fast the inital block wasn''t done.');
        write_mode=1;
    else
        bbytes=fhd.bbytes;
    end
else
    % bbytes is always 1024 for the first header because 
    % its not used then
    bbytes=0;
end

%agilent file headers are always 32 bytes big. 
header_size=32;
%agilent block headers are 28 bytes big.
block_header=28;
% 40 bytes of data after our headers
data_bits=40;

transfer_size=header_size+block_header+data_bits;

tmp_fid_tag=sprintf('/tmp/%s_%i_%i.fid',datestr(now,30),volume_number,ceil(rand(1)*10000));

local_tmp_fid_tag=tmp_fid_tag;
if ~isempty(getenv('TEMP'))
    local_tmp_fid_tag=strrep(local_tmp_fid_tag,'/tmp',getenv('TEMP'));
end

lin_dd_status=' status=noxfer';
lin_of=[' of=' tmp_fid_tag];
lin_append=' oflag=append';
mac_of='';
if ismac && local_operation_only
    lin_dd_status='';
    lin_of='';
    lin_append='';
    mac_of=['>> ' tmp_fid_tag];
end

%{
% command when run remotely (or locally, even) will pull bytes 1-26 and
% 29-102 of a fid (skipping the two bytes that represent the status of the
% whole fid, because those will change when the acq is done.
% This is a near replicate of the work done in check subvolume. Would
% be good to consolidate that, but that is for later.
% SKIPPING THE READY FLAGS
dd_cmd =  ['( dd bs=26' lin_dd_status ' count=1' lin_of mac_of...
    ' && dd' lin_dd_status ' bs=2 skip=1 count=0'...
    ' && dd' lin_dd_status ' bs=74 count=1' lin_of ' conv=notrunc' lin_append ' ) < ' input_fid mac_of];
%}
% always grab 100 bytes and we'll do a more accurate in matlab comparison
% intentionally ignoring only the status bits.
dd_prts={[' dd bs=' num2str(header_size)  lin_dd_status ' count=1' lin_of mac_of]};
if bbytes
    dd_prts{end+1}=['dd ' lin_dd_status ' bs=' num2str(bbytes)  ' skip=' num2str(volume_number-1) ' count=0'];
end
dd_prts{end+1}=['dd ' lin_dd_status ' bs=' num2str(block_header+data_bits) ' count=1' lin_of ' conv=notrunc' lin_append];
dd_cmd = ['( ' strjoin(dd_prts,' && '),' ) < ' input_fid mac_of];

if local_operation_only
    % runs dd command locally
    [s, dd_out] = system(dd_cmd);
    assert(s==0,sprintf('dd fail %s',dd_out));
else
    % runs dd command remotely.
    ssh_dd=sprintf('ssh %s@%s "%s"',user,scanner,dd_cmd);
    % fetches the fid file
    scp_fid=sprintf('scp -p %s@%s:%s %s',user,scanner,tmp_fid_tag,local_tmp_fid_tag);
    ssh_call(ssh_dd);
    ssh_call(scp_fid);
end

file_meta=dir(local_tmp_fid_tag);%gets metadata, especially file bytes.
if file_meta.bytes ~= transfer_size
    error('Problem with the copy/transfer! temporary file is %s',remote_temp_fidpath);
else
    [tfhd.npoints, tfhd.nblocks, tfhd.ntraces, tfhd.bitdepth, ...
        tfhd.bbytes, tfhd.complete_file_size, ...
        tbhd] = load_fid_hdr(local_tmp_fid_tag);
    % blk_hdr.status
    %tready=bitget(tbhd.status,1);
    tready=tbhd.status.hasData;
    if ~tready
        return;
    end
    if write_mode
        consistency_status = 1;
        % set NON friendly permisions to file
        % BECAUSE OVERWRITES OF THIS TAG ARE DANGEROUS!
        chmod_cmd=sprintf('chmod 444 %s',local_tmp_fid_tag);
        [~,~] = system(chmod_cmd); % set perms
        [~,~] = system(sprintf('mv %s %s',local_tmp_fid_tag,fid_tag_path));
    else
        % we already made sure the base comparison tag is ready.
        diff_cmd = sprintf('diff -q %s %s',fid_tag_path,local_tmp_fid_tag);
        [s,diff_result] = system(diff_cmd);
        if isempty(diff_result) || s==0
            consistency_status = 1;
        end
        % assert(s==0,sprintf('fid tag compare fail %s',diff_result));
        tmp_rm_cmd = sprintf('rm %s',local_tmp_fid_tag);
        [s, tmp_rm_out] = system(tmp_rm_cmd);
        assert(s==0,sprintf('dd fail %s',tmp_rm_out));
    end
    if ~local_operation_only
        % removes temp fid remotely.
        ssh_rm_cmd=sprintf('ssh %s@%s rm %s',user,scanner,tmp_fid_tag);
        [s, tmp_rm_out]  = ssh_call(ssh_rm_cmd);
        assert(s==0,sprintf('dd fail %s',tmp_rm_out));
    end
end

end

