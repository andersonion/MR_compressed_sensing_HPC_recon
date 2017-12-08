function [ input_fid, local_or_streaming_or_static ] = find_input_fidCS( scanner,runno,study,agilent_series,user )
%
% local_or_streaming_or_static: 1 => local fid found, 2 -> using fid of in-progress scan, 3 -> using fid in its remote static location;
if ~exist('user','var')
    user='omega';
end
local_or_streaming_or_static = 3;
scratch_drive = getenv('BIGGUS_DISKUS'); % Currently, this is /glusterspace.
workdir = fullfile(scratch_drive,[runno '.work/']);
local_fid = [workdir runno '.fid'];
if exist(local_fid,'file')
    input_fid = local_fid;
    local_or_streaming_or_static = 1;
else
    finished_acq_path=['/home/mrraw/' study '/' agilent_series '.fid/fid'];
    current_fid_size=get_remote_filesize(finished_acq_path,scanner);% check final destination
    if (current_fid_size == 0)
        local_or_streaming_or_static = 2;
        % I think using tail in ssh call is generating bogus status codes.
        % Will approximate this behavior inside matlab by taking last item.
        find_file_cmd=['ssh ' user '@' scanner ' "ls -tr /home/vnmr1/vnmrsys/exp*/acqfil/fid | tail -n1"'];
        [~,result]=ssh_call(find_file_cmd);
        latest_fid=result(1:end-1);
        input_fid=latest_fid;
        %}
        %{
        % This command continued to have trouble, going to try switching to
        a find command. 
        inprogress_fid_cmd=['ssh ' user '@' scanner ' ls -tr /home/vnmr1/vnmrsys/exp*/acqfil/fid'];
        [~,inprogress_fids]=ssh_call(inprogress_fid_cmd);
        inprogress_fids=strsplit(inprogress_fids);
        input_fid=inprogress_fids{end-1};
        %}
        %{
        find_file_cmd=['ssh ' user '@' scanner ' "$(find  /home/vnmr1/vnmrsys/ -type d -maxdepth 1 -name \"exp*\") | tail -n1"'];
        [~,result]=ssh_call(find_file_cmd);
        latest_fid=result(1:end-1);
        input_fid=latest_fid;
        %}
    else
        input_fid=finished_acq_path;
    end
end
end

