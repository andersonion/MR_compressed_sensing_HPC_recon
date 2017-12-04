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
    % to use copy-id to new systems we need rsa keys.
    if ~exist(sprintf('/home/%s/.ssh/id_rsa.pub',getenv('USER')),'file')
        system('ssh-keygen -q');
    end
    
    remote_cmd = ['ssh omega@' remote_machine ' ' main_cmd];

else
    remote_cmd = main_cmd;
end

[status,file_size_in_bytes] = system(remote_cmd);

if exist('remote_machine','var')
        logged=0;
        [status,file_size_in_bytes] = system(remote_cmd);
        %{
        %James commented this out becuase it wasnt working, well one of these multi-ssh calls wasnt, and this is the first try.
        for tt = 1:50
            if status
                [status,file_size_in_bytes] = system(remote_cmd);
            else
                if ~logged
                    if tt > 1
                        log_msg = sprintf('NOTE: Potential network issues encountered: it has taken %i tries to get a successful response from %s.\n',tt,scanner);
                        disp(log_msg)
                        %log_mode = 1;
                        %yet_another_logger(log_msg,log_mode,log_file);
                    end
                    logged=1;
                end
            end
        end
        
        if status
            %error_flag=1;
            log_msg=sprintf('Failure due to network connectivity issues; unsuccessful communication with %s.\n',scanner);
            %yet_another_logger(log_msg,log_mode,log_file,error_flag);
            disp(log_msg)
            error_due_to_network_issues
            %quit
        end
        %}
end


file_size_in_bytes = strtrim(file_size_in_bytes);
if isstrprop(file_size_in_bytes,'digit')
    file_size_in_bytes = str2double(file_size_in_bytes);
else
    file_size_in_bytes = 0;
end

end

