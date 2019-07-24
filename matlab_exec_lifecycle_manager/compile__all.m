function compile__all(P)
% compile all
% hacky script to run all compile_commands in the specified directory. 
% This expects all the compile_command_* scripts to be in the same directory.
% If your compile commands need paths set there should be a
% compile__pathset.m in that same folder.
% (that requirement is set by compile_command__all_purpose)
% 
% THIS FUNCTION MUST BE ON YOUR PATH BEFORE IT RUNS.
% 
% noteworthy it uses shell parallelism to run them all agnostic of the work
% they do.
if ~exist('P','var')
    P=pwd;
else
    init_dir=pwd;
    cd(P);
    P=pwd;
    cleaner=cell(0);
    cleaner{end+1} = onCleanup(@() cd(init_dir));
end
% could capture current path using following. but really its SUPER messy to
% try to do that kinda stuff.
% Best case is all related compile commands live in same directory
% AND we assume that you're in their directory when you run them.
% c_p=path();
parallel=1;
[~,c_commands]= system(sprintf('find %s -name "compile_command_*.m"|grep -v "__"',P))
c_commands=strsplit(strtrim(c_commands));
disp(c_commands');
pause(1);
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
    %% parallel run using shell parllelism, waiting for completion.
    % this might be cleaner if we just made a shellscript to do this work
    % rather than using system several times over.
    % Its kind of nice to do multi-system calls as that lets us debug a bit
    % in matlab.
    list_active_compiles_cmd=sprintf('ps -ef|grep -i matlab |grep %s |grep compile_command\n',getenv('USER'));
    warning('Background_compile starting! compile logs will be in /tmp/');
    for c=1:numel(c_commands)
        [~,n]=fileparts(c_commands{c});
        if ~isempty(c_commands{c})
            system(sprintf('matlab -nodisplay -nosplash -nodesktop -r "addpath(''%s'');addpath(''%s'');run %s;exit" -logfile /tmp/%s.log & ',P,fileparts(mfilename('fullpath')),c_commands{c},n));
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
% the "old" way of just running each named function in turn.
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
