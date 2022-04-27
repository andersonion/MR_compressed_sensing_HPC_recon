%compile me
function compile_command_cleanup
exec_env_var='CS_VOLUME_CLEANUP_EXEC';
%  'read_header_of_CStmp_file.m'
include_files = {
    'deploy_procpar_handlers.m'
    };
compile_command__allpurpose('volume_cleanup_for_CSrecon_exec.m',include_files,exec_env_var);
