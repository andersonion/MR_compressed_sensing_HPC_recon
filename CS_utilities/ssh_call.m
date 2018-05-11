function [status,stdout]=ssh_call(ssh_cmd)
% This probably belongs someplace else, like the group common utils...

% Need to add these options to suppress any password prompt and let this fail
% copied right out of one of hte workstation_code hdlpers, ...scp_single_thing...
% ssh_opts=" -o BatchMode=yes -o ConnectionAttempts=1 -o ConnectTimeout=1 -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=0 -o PasswordAuthentication=no";
% 
ssh_opts=' -o BatchMode=yes -o ConnectionAttempts=1 -o ConnectTimeout=1 -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=0 -o PasswordAuthentication=no';
idx=strfind(ssh_cmd,'ssh');
if isempty(idx)
    idx=strfind(ssh_cmd,'scp');
end
ssh_cmd=sprintf('%s %s %s',ssh_cmd(1:idx(1)+3),ssh_opts,ssh_cmd(idx(1)+3:end));



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
