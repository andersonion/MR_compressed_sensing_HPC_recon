%compile me
function compile_command_streaming_CSrecon_main
%exec_env_var='';%optional shell env var to be cleared.
%{
include_files = {[ getenv('WORKSTATION_CODE'), '/recon/CS_v2/gui_info_collect.m'     
    [ getenv('WORKSTATION_CODE'), '/recon/CS_v2/puller_glusterspaceCS_2.m' 
    [ getenv('WORKSTATION_CODE'), '/recon/CS_v2/extract_info_from_CStable.m'
    [ getenv('WORKSTATION_CODE'), '/recon/CS_v2/zpad.m'
    [ getenv('WORKSTATION_CODE'), '/recon/CS_v2/CS_utilities/get_reservation.m'
    };%optional, but required if using exec_env_var, can be empty.
%}
include_files={
    '/cm/shared/apps/MATLAB/R2021b/toolbox/signal/signal/hamming.m' 
    '/cm/shared/apps/MATLAB/R2021b/toolbox/images/images/padarray.m'
    };
function_name='streaming_CS_recon_main_exec.m';
compile_dir=compile_command__allpurpose(function_name,include_files);%,exec_env_var);

code_dir=fileparts(which(function_name));
original_builtin_script = 'run_streaming_CS_recon_main_exec_builtin_path.sh';
original_builtin_path=fullfile(code_dir,'bin',original_builtin_script);

% This has been modified to use a shell script which checks for CS_CODE_DEV
% env var, and runs the desired veresion. Defaults to stable if
% unspecified, when developing code, use latest.
% update_bin_cmd=sprintf('cp %s %s/;rm %s;ln -s %s/%s %s',original_builtin_path,compile_dir,bin_path,compile_dir,original_builtin_script,bin_path)
% system(update_bin_cmd);
if exist(compile_dir,'dir')
    update_bin_cmd=sprintf('cp -p %s %s/',original_builtin_path,compile_dir);
    system(update_bin_cmd);
end
