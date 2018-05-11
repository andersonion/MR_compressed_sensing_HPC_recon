%compile me
function compile_dir=compile_command__allpurpose_singlethread(source_filename,include_files,exec_env_var)
%% input handle
[~,source_name]=fileparts(source_filename);
[~,tok]=regexpi(source_filename,'(.*)(_exec).m', 'match', 'tokens');
[~,tok2]=regexpi(source_filename,'(.*).m', 'match', 'tokens');
if ~isempty(tok)
    script_name=tok{1}{1};
elseif ~isempty(tok2)
    script_name=tok2{1}{1};
else
    error('Please give complete mfilename');
end
source_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
source_file = fullfile(source_dir ,source_filename);

include_string='';
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
compile_time=sprintf('%04i%02i%02i_%02i%02i%02i',ts(1:5));
run compile__pathset.m
exec_name=[ script_name '_executable'];
this_exec_base_dir=fullfile(matlab_execs_dir,exec_name);
latest_path_link = fullfile(this_exec_base_dir,'latest');
%% check for previously compiled
% this is neat, EXCEPT it doesnt account for dependent files!!!!!!!!!!!
% matlab has auto-dependecny finding, should use that to get list of
% dependney funcitons so we can do a true exec diff.
[diff_stat,out]=system(sprintf('f1=%s;f2=%s;ls -l $f1 $f2;diff -qs $f1 $f2',source_file,fullfile(latest_path_link,source_filename)));
if ~diff_stat
    disp(sprintf('skipping %s',source_filename));
    return;
else
    disp(out);
end
%% prep dir
compile_dir = fullfile(this_exec_base_dir,compile_time);
system(['mkdir -m 775 ' compile_dir]);
%% do the mcc
disp('Running mcc, this takes a bit...');
%-R -singleCompThread 
eval(['mcc -N -d  ' compile_dir...
   ' -C -m '...
   ' -R -singleCompThread -R nodisplay -R nosplash -R nojvm '...
   ' ' include_string ' '...
   ' ' source_file ';']) 
%% copy files in so we can do diff check easily(eg check if we need to compile).
cp_cmd = sprintf('cp -p %s %s %s',source_file,strjoin(include_files,' '),compile_dir);
system(cp_cmd);
%% unpack mcr
[~,n,~]=fileparts(source_filename);
first_run_cmd = fullfile(compile_dir ,['/run_' n '.sh ' ]);
first_run_cmd = [first_run_cmd matlab_path];
system(first_run_cmd);
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
%% link to latest
if exist(latest_path_link,'dir')
    rm_ln_cmd = sprintf('unlink %s',latest_path_link);
    system(rm_ln_cmd)
end
ln_cmd = sprintf('ln -s %s %s',compile_dir,latest_path_link);
system(ln_cmd);