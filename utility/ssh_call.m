function [status,stdout]=ssh_call(ssh_cmd,fail_on_error)
% This probably belongs someplace else, like the group common utils...
% purpose is act just like system and splice in ssh options to scp/ssh calls 
% failing on errors.
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
if ~exist('fail_on_error','var')
    fail_on_error=true;
end

% Need to add these options to suppress any password prompt and let this fail
% copied right out of one of the workstation_code hdlpers, ...scp_single_thing...
% ssh_opts=" -o BatchMode=yes -o ConnectionAttempts=1 -o ConnectTimeout=1 -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=0 -o PasswordAuthentication=no";
% 
ssh_opts=' -o BatchMode=yes -o ConnectionAttempts=1 -o ConnectTimeout=1 -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=0 -o PasswordAuthentication=no';
idx=strfind(ssh_cmd,'ssh');
if isempty(idx)
    idx=strfind(ssh_cmd,'scp');
end
ssh_cmd=sprintf('%s %s %s',ssh_cmd(1:idx(1)+3),ssh_opts,ssh_cmd(idx(1)+3:end));
% insert cygpath dealing here? BAD idea to blanket cygpath :p should be
% based on remote platform. Best behavior is taht our input commands should
% be properly quoted already. 
%t=strrep(ssh_cmd,'''','\''');
%[s,sout]=sprintf('cygpath -l ''%s''',t);
% if s~=0 
% % no err status, presume cygpath worked, and was useful'

[status,stdout]=system(ssh_cmd);
if status&&fail_on_error
    %error_flag=1;
    log_msg=sprintf([ 'SSH returned error;\n%s\nFull ssh cmd (%s).\n' ...
        'Verify job did not run on cluster nodes, they may not have external access.'], ...
        stdout, ssh_cmd);
    %yet_another_logger(log_msg,log_mode,log_file,error_flag);
    disp(log_msg)
    % throw as caller here? Becuase that is far less yucky?
    error(log_msg);
    error_due_to_network_issues
    %quit force
end

end
