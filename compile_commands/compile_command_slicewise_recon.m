%compile me
function compile_command_slicewise_recon
%exec_env_var='';%optional
include_files = {'/cm/shared/workstation_code_dev/recon/CS_v2/CS_utilities/read_header_of_CStmp_file.m' 
    '/cm/shared/apps/MATLAB/R2015b/toolbox/stats/stats/quantile.m'
    };%optional, but required if using exec_env_var.
compile_command__allpurpose_singlethread('slicewise_CSrecon_exec.m',include_files);%,exec_env_var);
