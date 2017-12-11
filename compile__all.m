% compile all

parallel=1;
[~,c_commands]= system('find . -name "compile_command_*.m"|grep -v "__"')
c_commands=strsplit(c_commands);
if ~parallel
    %% serial run of compile commands in matlab
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
    %% parallel run using shell parllelism, unfortunately doesnt wait for completion yet.
    warning('Background_compile starting! compile logs will be in /tmp/');
    for c=1:numel(c_commands)
        if ~isempty(c_commands{c})
            system(sprintf('matlab -nodisplay -nosplash -nodesktop -r "run %s;exit" -logfile /tmp/%s.log & ',c_commands{c},c_commands{c}));
        end
    end
    fprintf('Run following command to see when background compiles are done\n');
    fprintf('ps -ef|grep -i matlab |grep %s |grep compile_command\n',getenv('USER'));
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
