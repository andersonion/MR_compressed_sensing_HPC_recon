function compile_dir=compile_command__allpurpose(source_filename,include_files,exec_env_var,mcc_opts)
% compile_dir=COMPILE_COMMAND__ALLPURPOSE(source_filename,include_files,exec_env_var)
% helps manage matlab executables building and versioning
% copies all dependent source code into the exec. 
%
% source_filename - matlab function(source file or full path)
% include_files - arbitrary files to add to your exec, and
% exec_env_var - an env var to be cleared before the unpack/run code.
%
% your code files should be first on the path OR there should be a
% compile__pathset.m file in the current directory.
%
% When paired with compile__all, it will switch to the expected
% compile_commands directory, letting you keep the compile_commands.* and
% compile__pathset.m function in the same directory.
% compile__all and compile_commands__allpurpose should be on the path for
% reliable behavior (esp when there are multiple versions of code flying
% around).
% 
% that need not be a permanent path setting, just for the "right" now.

% java.opts could use improvement, routinely only has -Xmx64G in it.
j_opts_path='/cm/shared/workstation_code_dev/shared/pipeline_utilities/java.opts';
%% input handle
% if there is a custom path setting for this code run that now.
pathing_script=which('compile__pathset');
run(pathing_script);
[source_dir,source_name]=fileparts(which(source_filename));
% Force trimming exec or executable off the name of the input (if its
% there).
% executeable will be appended later. 
% this keeps us free of forced naming conventions for the source file.
[~,tok]=regexpi(source_name,'(.*)(_exec.*)(.m)?', 'match', 'tokens');
[~,tok2]=regexpi(source_name,'(.*)(.m)?', 'match', 'tokens');
if ~isempty(tok)
    script_name=tok{1}{1};
elseif ~isempty(tok2)
    script_name=tok2{1}{1};
else
    error('Please give complete mfilename, OR only function_name(.m)?');
end
if strcmp(source_dir,'')
    warning('Guessing the old fasioned source directory!');
    source_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
end
source_file = [fullfile(source_dir ,source_name) '.m'];
if ~exist(source_file,'file')
    error('didnt find source_file %s',source_file);
else
    [d,n,e]=fileparts(source_file);
    path_tree=cell(0);
    while ~isempty(n)
        path_tree{end+1}=n;
        [d,n,e]=fileparts(d);
    end
    path_tree=path_tree(end:-1:1);
    path_tree{end+1}='---';
    path_tree{end+1}='This is the path tree for your source';
    path_tree{end+1}='  if it looks wrong press ctrl+c now';
    disp(path_tree');
    pause(2);
end
if ~exist('mcc_opts','var')
    mcc_opts='';
end
% source_dir is now the directory of our file to compile
% source_name is now the name of the function/script ( no .m)
% source_file is now the full path to the script
%              ( source_dir/source_name.m )
% script_name is the function name without any exec/executable
%% auto-resolve required files
include_java = 0;
include_string='';
required_files=matlab.codetools.requiredFilesAndProducts(source_file);
include_files=reshape(include_files,[1,numel(include_files)]);
include_files=unique([include_files required_files]);
for ff=1:numel(include_files)
    [s,out]=system(['grep GzipRead ' include_files{ff}]);
    if ~s && ~strcmp(out,'')
        include_java =1 ;
        break
    end
end

if include_java
    include_files=[include_files {[getenv('WKS_SHARED') '/civm_matlab_common_utils/GzipRead.java']...
        [getenv('WKS_SHARED') '/civm_matlab_common_utils/GzipRead.class']}];
end

if exist('include_files','var') && ~isempty(include_files)
    include_string=sprintf(' -a %s',strjoin(include_files,' -a '));
else
    include_files={};
end
if exist('exec_env_var','var')
    setenv(exec_env_var,'')
end
%% sys evn handle
matlab_path = matlabroot();
matlab_execs_dir=getenv('MATLAB_EXEC_PATH');
if isempty(matlab_execs_dir)
    matlab_execs_dir = fullfile(getenv('WORKSTATION_HOME'),'matlab_execs');
end
%% var set
ts=fix(clock);
% this sprintf has the formatting to print seconds, but we ignore them by
% selecting only the first 5 elements, the effect is they are just not
% printed. 
compile_time=sprintf('%04i%02i%02i_%02i%02i%02i',ts(1:5));
exec_name=[ script_name '_executable'];
this_exec_base_dir=fullfile(matlab_execs_dir,exec_name);
latest_path_link = fullfile(this_exec_base_dir,'latest');
%% check for previously compiled
% diff on main and attempt to account for dependent files
prev_source_file=fullfile(latest_path_link,[source_name '.m']);
[diff_stat,out]=system(sprintf('f1=%s;f2=%s;ls -l $f1 $f2;diff -qs $f1 $f2',...
    source_file,prev_source_file ));
include_diff=0;
if exist('simple_time_check','var')
    % skip a full diff by checking if the main script file is the newest.
    % nice idea, except we'd never reset our output, so if the includes
    % were ever newer, they'd stay newer : ( 
    [ls_stat,time_check]=system(sprintf('ls -tr %s %s',source_file,strjoin(include_files,' ')));
    time_check=strsplit(strtrim(time_check));
    if ~ls_stat && ~strcmp(time_check{end},source_file)
        include_diff=1;
    end
else
    incl_out=cell(size(include_files));
    for ff=1:numel(include_files)
        [~,in,ie]=fileparts(include_files{ff});
        prev_include_file=fullfile(latest_path_link,[in ie]);
        [s,incl_out{ff}]=system(sprintf('diff -qr %s %s',include_files{ff},prev_include_file));
        include_diff=include_diff+s;
    end
end
if ~diff_stat && ~include_diff
    % if main is not different and it is the newest file.
    disp(sprintf('skipping %s',source_filename));
    compile_dir='NOT COMPILED DUE TO MAIN FILE IS THE SAME';
    return;
else
    disp(out);
end

%% prep dir
compile_dir = fullfile(this_exec_base_dir,compile_time);
% we force this directory to be friendly because it doesnt leak any code by
% default
system(['mkdir -pm 775 ' compile_dir]);
%% do the mcc
disp('Running mcc, this takes a bit...');
%-R -singleCompThread 
eval(['mcc -N -d  ' compile_dir...
   ' -C -m '...
   ' -R nodisplay -R nosplash -R nojvm '...
   mcc_opts ...
   ' ' include_string ' '...
   ' ' source_file ';']) 

%% unpack mcr
[~,n,~]=fileparts(source_filename);
if ~strcmp(n,source_name)
    % silly double check for bad variable conventions, in the future the
    % fileparts and this if condition can be removed. 
    error('auto naming mis-match inputlike %s is not the same as %s',source_name,n);
end
shell_script= fullfile(compile_dir ,['/run_' source_name '.sh ' ]);
% redirect to bit bucket to avoid the confusion it'll generate if we watch
% this.
first_run_cmd = sprintf('%s %s &> /dev/null',shell_script,matlab_path);
system(first_run_cmd);

if include_java
    include_files=[include_files j_opts_path];
end
%% copy files in so we can do diff check easily(eg check if we need to compile).
% source files are given the same permissions as the input, 
% so they will only be accesible to the same group. This is a good thing.
% To distribute the source files should be pruned.
cp_cmd = sprintf('cp -p %s %s %s',source_file,strjoin(include_files,' '),compile_dir);
[s,r]=system(cp_cmd);
if s
    disp('failed to preserve code in exec, we''ll let this proceed to be a valid exec setup.');
    disp(r);
end

%% fix permissions
% this formerly made wide open friendly permissions... well poo poo to
% that! Adjusted these to ONLY make the mcr extraction friendly.
permission_fix_cmds = { ...
    % grant read + traversal to all directories in this compile_dir
    sprintf('find %s -type d -exec chmod a+rx {} \\; ',compile_dir)
    % grant read+execute to all sh files in this compile_dir
    sprintf('find %s -type f -name "*.sh" -exec chmod a+rx {} \\; ',compile_dir)
    % grant read and execute to our compiled source file (not its
    % sourcecode)
    sprintf('find %s -type f -name "%s" -exec chmod a+rx {} \\; ',compile_dir,source_name)
    % grant read access to all files in the mcr(they're binary bits so
    % thats good)
    sprintf('find %s/*_mcr -type f -exec chmod a+r {} \\; ',compile_dir)
    % grant group write to all files in the mcr ( matlab occasionaly
    % decides it has to re-extract the mcr cache files and this fixes it to
    % at least let the group owner repair that)
    sprintf('find %s/*_mcr -type f -exec chmod g+w {} \\; ',compile_dir)
    };
[s,r]=system(strjoin(permission_fix_cmds,';'));
if s
    disp(r);
end

%% Edit run_*.sh script to put java.opts in right place at runtime (optional)
if include_java   
    cp_string='cp -n \${exe_dir}/java.opts \.';
    rm_string='if [[ -e ./java.opts ]]; then rm ./java_opts ; fi';
    j_cmd=['perl -pi -e ''s:^(\s*)(eval.*$):${1}' cp_string '\n${1}${2}\n${1}' ...
        rm_string '\n:'' ' shell_script ];
    system(j_cmd);
end

%% Give a proper return code to the shell code which runs the runtime+mcr bundle
ret_code='ret_code=\$?';
rc_cmd=['perl -pi -e ''s/(\s*)(eval.*$)/$1$2\n$1' ret_code '\n/'' ' shell_script ];
system(rc_cmd);

rc2_cmd=['perl -pi -e ''s/^exit/exit \${ret_code}\n/'' ' shell_script ];
system(rc2_cmd);

%% link to latest
if exist(latest_path_link,'dir')
    rm_ln_cmd = sprintf('unlink %s',latest_path_link);
    system(rm_ln_cmd)
end
ln_cmd = sprintf('ln -s %s %s',compile_dir,latest_path_link);
[s,r]=system(ln_cmd);
if s
    disp(r);
else
    % add a "success" flag so we can better clean up failures.
    system(spintf('touch %s/compile_success',latest_path_link));
end