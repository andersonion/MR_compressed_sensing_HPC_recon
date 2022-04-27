%compile me
function compile_command_setup
%exec_env_var='';%optional shell env var to be cleared.

% 'read_header_of_CStmp_file.m' ...
include_files = {
    'quantile.m' ...
    'CS_allocate_temp_file.m' ... 
    'init.m'
    };%optional, but required if using exec_env_var, can be empty.
compile_command__allpurpose('setup_volume_work_for_CSrecon_exec.m',include_files);%,exec_env_var);
