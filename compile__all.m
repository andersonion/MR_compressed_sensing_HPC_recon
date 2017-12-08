% compile all
% could find all "compile_* files in here, but didnt bother.
addpath([getenv('WORKSTATION_HOME') '/recon/WavelabMex']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/simulation']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/threshold']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/utils']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/testing_and_prototyping']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/CS_utilities']);

parallel=0;

if ~parallel
    % c_commands = ls('compile_command_*');
    [~,c_commands]= system('find . -name "compile_command_*"')
    c_commands=strsplit(c_commands);
    for c=1:numel(c_commands)
        if ~isempty({c})
            try
                run(c_commands{c});
            catch exc
                exceptions{c}=exc;
                disp(exc);
            end
        end
    end
else
    c_commands = ls('compile_command_*');
    c_commands=strsplit(c_commands);
    parfor c=1:numel(c_commands)
        if ~isempty(c_commands{c})
            cx=strsplit(c_commands{c},'.');
            if exist(cx{1},'file')
                eval(cx{1});
            end
        end
    end
end
%%
stop;
    % compile_command_cleanup % In dev, pulled from current use.
    compile_command_fid_splitter
    compile_command_gatekeeper
    % compile_command_gui_test
    compile_command_local_filegatekeeper
    compile_command_procpar_processer
    compile_command_slicewise_recon
    compile_command_setup
    compile_command_streaming_CSrecon_main
    compile_command_volume_manager
    compile_command_cleanup
    
    % setup, main, 
