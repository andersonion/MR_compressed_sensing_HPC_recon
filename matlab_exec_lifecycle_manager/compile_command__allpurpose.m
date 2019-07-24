%compile me
function compile_dir=compile_command__allpurpose(source_filename,include_files,exec_env_var)
j_opts_path='/cm/shared/workstation_code_dev/shared/pipeline_utilities/java.opts';
%% input handle
[source_dir,source_name]=fileparts(source_filename);
[~,tok]=regexpi(source_name,'(.*)(_exec.*)(.m)?', 'match', 'tokens');
[~,tok2]=regexpi(source_name,'(.*)(.m)?', 'match', 'tokens');
if ~isempty(tok)
    script_name=tok{1}{1};
elseif ~isempty(tok2)
    script_name=tok2{1}{1};
else
    error('Please give complete mfilename');
end
if strcmp(source_dir,'')
    source_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
end
source_file = [fullfile(source_dir ,source_name) '.m'];

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
    include_files=[include_files {'/cm/shared/workstation_code_dev/shared/civm_matlab_common_utils/GzipRead.java'...
        '/cm/shared/workstation_code_dev/shared/civm_matlab_common_utils/GzipRead.class'}];
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
matlab_path = '/cm/shared/apps/MATLAB/R2015b';
matlab_execs_dir = fullfile(getenv('WORKSTATION_HOME'),'matlab_execs');
%% var set
ts=fix(clock);
% this sprintf has the formatting to print seconds, but we ignore them by
% selecting only the first 5 elements, the effect is they are just not
% printed. 
compile_time=sprintf('%04i%02i%02i_%02i%02i%02i',ts(1:5));
run compile__pathset.m
exec_name=[ script_name '_executable'];
this_exec_base_dir=fullfile(matlab_execs_dir,exec_name);
latest_path_link = fullfile(this_exec_base_dir,'latest');
%% check for previously compiled
% this is neat, EXCEPT it doesnt account for dependent files!!!!!!!!!!!
% matlab has auto-dependecny finding, should use that to get list of
% dependney funcitons so we can do a true exec diff.
[diff_stat,out]=system(sprintf('f1=%s;f2=%s;ls -l $f1 $f2;diff -qs $f1 $f2',source_file,[fullfile(latest_path_link,source_name) '.m']));
if ~diff_stat
    disp(sprintf('skipping %s',source_filename));
    compile_dir='NOT COMPILED DUE TO MAIN FILE IS THE SAME';
    return;
else
    disp(out);
end

%% prep dir
compile_dir = fullfile(this_exec_base_dir,compile_time);
system(['mkdir -pm 775 ' compile_dir]);
%% do the mcc
disp('Running mcc, this takes a bit...');
%-R -singleCompThread 
eval(['mcc -N -d  ' compile_dir...
   ' -C -m '...
   ' -R nodisplay -R nosplash -R nojvm '...
   ' ' include_string ' '...
   ' ' source_file ';']) 


%% unpack mcr
[~,n,~]=fileparts(source_filename);
shell_script= fullfile(compile_dir ,['/run_' n '.sh ' ]);
first_run_cmd = [shell_script matlab_path];
system(first_run_cmd);

if include_java
    include_files=[include_files j_opts_path];
end
%% copy files in so we can do diff check easily(eg check if we need to compile).
    cp_cmd = sprintf('cp -p %s %s %s',source_file,strjoin(include_files,' '),compile_dir);
system(cp_cmd);

%% fix permissions
permission_fix_cmds = { ...
    sprintf('find %s -type f -exec chmod a+r {} \\; ',compile_dir)
    sprintf('find %s -type f -name "*.sh" -exec chmod a+x {} \\; ',compile_dir)
    sprintf('find %s -type f -name "%s" -exec chmod a+x {} \\; ',compile_dir,source_name)
    sprintf('find %s -type f -exec chmod g+w {} \\; ',compile_dir)
    sprintf('find %s -type d -exec chmod a+rx {} \\; ',compile_dir)
    };
[s,r]=system(strjoin(permission_fix_cmds,';'));
if s
    disp(r);
end


%% Edit run_*.sh script to put java.opts in right place at runtime (optional)
if include_java   
    cp_string='cp -n \${exe_dir}/java.opts \.';
    rm_string='if [[ -e ./java.opts ]]; then rm ./java_opts ; fi';
    j_cmd=['perl -pi -e ''s:^(\s*)(eval.*$):${1}' cp_string '\n${1}${2}\n${1}' rm_string '\n:'' ' shell_script ]; 
    system(j_cmd);
end

%% Give a proper return code

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
system(ln_cmd);