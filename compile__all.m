% compile all
% could find all "compile_* files in here, but didnt bother.
addpath([getenv('WORKSTATION_HOME') '/recon/WavelabMex']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/simulation']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/threshold']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/utils']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/testing_and_prototyping']);

% compile_command_cleanup % In dev, pulled from current use.
compile_command_fid_splitter
compile_command_gatekeeper
% compile_command_gui_test
compile_command_local_filegatekeeper
compile_command_procpar_processer
compile_command_slicewise_recon
compile_command_streaming_CSrecon_main
compile_command_volume_manager
compile_command_setup