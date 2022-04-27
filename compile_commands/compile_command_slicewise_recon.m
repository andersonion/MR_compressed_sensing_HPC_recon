%compile me
function compile_command_slicewise_recon
% exec_env_var='';%optional
include_files = {% '/cm/shared/workstation_code_dev/recon/CS_v3/utility/read_header_of_CStmp_file.m' 
    which('quantile');
    };%optional, but required if using exec_env_var.
compile_command__allpurpose_singlethread('slicewise_CSrecon_exec.m',include_files);%,exec_env_var);

