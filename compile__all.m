% compile all

parallel=1;
[~,c_commands]= system(sprintf('find %s -name "compile_command_*.m"|grep -v "__"',pwd))
c_commands=strsplit(c_commands);
if ~parallel
    %% serial run of compile commands in matlab
    for c=1:numel(c_commands)
        if ~isempty({c})
            try
                run(c_commands{c});
            catch exc
                exceptions{c}=exc;o
                disp(exc);
            end
        end
    end
else
    %% parallel run using shell parllelism, unfortunately doesnt wait for completion yet.
    list_active_compiles_cmd=sprintf('ps -ef|grep -i matlab |grep %s |grep compile_command\n',getenv('USER'));
    warning('Background_compile starting! compile logs will be in /tmp/');
    for c=1:numel(c_commands)
        [~,n]=fileparts(c_commands{c});
        if ~isempty(c_commands{c})
            system(sprintf('matlab -nodisplay -nosplash -nodesktop -r "addpath(''%s'');run %s;exit" -logfile /tmp/%s.log & ',pwd,c_commands{c},n));
        end
    end
    [s,out]=system(list_active_compiles_cmd);out=strsplit(out,'\n');
    fprintf('Run following command to see when background compiles are done\n');
    fprintf('%s',list_active_compiles_cmd);
    fprintf('Trying to wait for completion automatically(normally takes less than 3 minutes).\n');
    while size(out,2)>2
        %fprintf('.');
        pause(5);
        [s,out]=system(list_active_compiles_cmd);disp(out);out=strsplit(out,'\n');
    end
    fprintf(' Done!\n');
    fprintf('auto-wait seems to have worked!\n');
end
%%
return;
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
