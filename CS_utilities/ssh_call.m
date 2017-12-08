function [status,stdout]=ssh_call(ssh_cmd)
% This probably belongs someplace else, like the group common utils...
    [status,stdout]=system(ssh_cmd);
    if status
        %error_flag=1;
        log_msg=sprintf('Failure due to network connectivity issues; Full ssh cmd (%s).\nVerify job did not run on nodes, they dont have internet access.',ssh_cmd);
        %yet_another_logger(log_msg,log_mode,log_file,error_flag);
        disp(log_msg)
        error_due_to_network_issues
        %quit
    end
end
