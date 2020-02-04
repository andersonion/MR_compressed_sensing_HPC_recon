function [cs_execs,exec_set]=CS_env_execs(set_var)
% [cs_execs,exec_set]=CS_env_execs(set_var)
% build paths to set of cs recon execs including env_var set_var in path.
% returns the paths in a struct, and the set chosen in exec_set
% 
% typically, exec_set will be stable.
% and we'll have struct members
%   gatekeeper
%   fid_splitter
%   volume_manager
%   volume_setup
%   volume_cleanup
%   slice_recon
%   procpar_gatekeeper
%   procpar_cleanup


%  May change this to look to environment variables, or a seperate
%  head/textfile, which will give us dynamic flexibility if our goal is
%  have end-to-end deployability.
% the CS_CODE_DEV setting cant be entirely in options as main is one of the
% "versioned" pieces of code.

% set an env var to get latest dev code, or will defacto run stable.
if ~exist('set_var','var')
    set_var='CS_CODE_DEV';
end
exec_set=getenv(set_var);
if isempty(exec_set)
    warning('Using default exec set ''stable''.');
    exec_set='stable';
end

cs_execs.gatekeeper = getenv('CS_GATEKEEPER_EXEC');
if isempty(cs_execs.gatekeeper)
    cs_execs.gatekeeper = [ '/cm/shared/workstation_code_dev/matlab_execs/gatekeeper_executable/' exec_set '/run_gatekeeper_exec.sh'] ;
    setenv('CS_GATEKEEPER_EXEC',cs_execs.gatekeeper);
end
cs_execs.fid_splitter = getenv('CS_FID_SPLITTER_EXEC');
if isempty(cs_execs.fid_splitter)
    cs_execs.fid_splitter = [ '/cm/shared/workstation_code_dev/matlab_execs/fid_splitter_executable/' exec_set '/run_fid_splitter_exec.sh' ];
    setenv('CS_FID_SPLITTER_EXEC',cs_execs.fid_splitter);
end
cs_execs.volume_manager = getenv('CS_VOLUME_MANAGER_EXEC');
if isempty(cs_execs.volume_manager)
    cs_execs.volume_manager = [ '/cm/shared/workstation_code_dev/matlab_execs/volume_manager_executable/' exec_set '/run_volume_manager_exec.sh'];
    setenv('CS_VOLUME_MANAGER_EXEC',cs_execs.volume_manager);
end
cs_execs.volume_setup = getenv('CS_VOLUME_SETUP_EXEC'); % Error check for isempty?
if isempty(cs_execs.volume_setup)
    cs_execs.volume_setup = ['/cm/shared/workstation_code_dev/matlab_execs/setup_volume_work_for_CSrecon_executable/' exec_set '/run_setup_volume_work_for_CSrecon_exec.sh' ];
    setenv('CS_VOLUME_SETUP_EXEC',cs_execs.volume_setup);
end
cs_execs.slice_recon = getenv('CS_SLICEWISE_RECON_EXEC'); % Error check for isempty?
if isempty(cs_execs.slice_recon)
    cs_execs.slice_recon = ['/cm/shared/workstation_code_dev/matlab_execs/slicewise_CSrecon_executable/' exec_set '/run_slicewise_CSrecon_exec.sh'] ;
    setenv('CS_SLICEWISE_RECON_EXEC',cs_execs.slice_recon);
end
cs_execs.volume_cleanup = getenv('CS_VOLUME_CLEANUP_EXEC'); % Error check for isempty?
if isempty(cs_execs.volume_cleanup)
    cs_execs.volume_cleanup = ['/cm/shared/workstation_code_dev/matlab_execs/volume_cleanup_for_CSrecon_executable/' exec_set '/run_volume_cleanup_for_CSrecon_exec.sh'];
    setenv('CS_VOLUME_CLEANUP_EXEC',cs_execs.volume_cleanup);
end
cs_execs.procpar_gatekeeper = getenv('CS_PROCPAR_GATEKEEPER_EXEC'); 
if isempty(cs_execs.procpar_gatekeeper)
    cs_execs.procpar_gatekeeper =['/cm/shared/workstation_code_dev/matlab_execs/local_file_gatekeeper_executable/' exec_set '/run_local_file_gatekeeper_exec.sh'];
    setenv('CS_PROCPAR_GATEKEEPER_EXEC',cs_execs.procpar_gatekeeper);
end
cs_execs.procpar_cleanup = getenv('CS_PROCPAR_CLEANUP_EXEC');
if isempty(cs_execs.procpar_cleanup)
    cs_execs.procpar_cleanup=['/cm/shared/workstation_code_dev/matlab_execs/process_headfile_CS_executable/' exec_set '/run_process_headfile_CS.sh'];
    setenv('CS_PROCPAR_CLEANUP_EXEC',cs_execs.procpar_cleanup);
end