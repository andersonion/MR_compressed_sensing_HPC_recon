function [ file_size_in_bytes] = get_remote_filesize( remote_path,remote_machine )
%   Returns the size of a specified folder on a local or remote machine,
%   If any errors are encountered, a 0 will be returned (let this not be
%   confused with "success").
%
%   Additional work is done such that, for a given cluster user, omega's
%   password on the remote machine should only need to be entered once.
%   It is unclear how the password prompt will be handled if this is part
%   of a compiled MATLAB executable.


main_cmd = ['wc -c ' remote_path ' | cut -d '' '' -f1 ']; % -f4 worked on rootbeerfloat instead of -f1

if exist('remote_machine','var')
    remote_cmd = ['ssh omega@' remote_machine ' ' main_cmd];
else
    remote_cmd = main_cmd;
end
[~,file_size_in_bytes]=ssh_call(remote_cmd);
file_size_in_bytes = strtrim(file_size_in_bytes);
if isstrprop(file_size_in_bytes,'digit')
    file_size_in_bytes = str2double(file_size_in_bytes);
else
    file_size_in_bytes = 0;
end

end

