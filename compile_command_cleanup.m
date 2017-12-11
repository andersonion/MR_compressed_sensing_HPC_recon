%compile me
function compile_command_cleanup
exec_env_var='CS_VOLUME_CLEANUP_EXEC';
include_files = {'/cm/shared/workstation_code_dev/recon/CS_v2/CS_utilities/read_header_of_CStmp_file.m'};
compile_command__allpurpose('volume_cleanup_for_CSrecon_exec.m',include_files,exec_env_var);
