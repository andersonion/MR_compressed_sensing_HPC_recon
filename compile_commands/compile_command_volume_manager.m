%compile me
function compile_command_volume_manager
exec_env_var='CS_VOLUME_MANAGER_EXEC';
include_files = {'/cm/shared/workstation_code_dev/recon/CS_v2/utility/read_header_of_CStmp_file.m'
  '/cm/shared/workstation_code_dev/recon/CS_v2/utility/ssh_call.m'
  '/cm/shared/workstation_code_dev/recon/CS_v2/deploy_procpar_handlers.m'
  '/cm/shared/workstation_code_dev/recon/CS_v2/utility/get_reservation.m'
  };
compile_command__allpurpose('volume_manager_exec.m',include_files,exec_env_var);
