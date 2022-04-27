%compile me
function compile_command_volume_manager
exec_env_var='CS_VOLUME_MANAGER_EXEC';
include_files = {
    % 'read_header_of_CStmp_file.m'
  'ssh_call.m'
  'deploy_procpar_handlers.m'
  'get_reservation.m'
  'wks_settings.m'
  'scanner.m'
  
  };
compile_command__allpurpose('volume_manager_exec.m',include_files,exec_env_var);
