%compile me
function compile_command_gatekeeper
%exec_env_var='';%optional shell env var to be cleared.
%include_files = {};%optional, but required if using exec_env_var, can be empty.
compile_command__allpurpose('gatekeeper_exec.m');%,include_files,exec_env_var);
