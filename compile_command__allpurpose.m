%compile me
function compile_command__allpurpose(source_filename,include_files,exec_env_var)
%% input handle
[~,tok]=regexpi(source_filename,'(.*)(_exec).m', 'match', 'tokens');
script_name=tok{1}{1};
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
source_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
matlab_path = '/cm/shared/apps/MATLAB/R2015b';
matlab_execs_dir = fullfile(getenv('WORKSTATION_HOME'),'matlab_execs');
%% var set
ts=fix(clock);
compile_time=sprintf('%04i%02i%02i_%02i%02i%02i',ts(1:5));
run compile__pathset.m
this_exec_base_dir=fullfile(matlab_execs_dir,[ script_name '_executable']);
%% prep dir
compile_dir = fullfile(this_exec_base_dir,compile_time);
system(['mkdir -m 775 ' compile_dir]);
source_file = fullfile(source_dir ,source_filename);
%% do the mcc
disp('Running mcc, this takes a bit...');
%-R -singleCompThread 
eval(['mcc -N -d  ' compile_dir...
   ' -C -m '...
   ' -R nodisplay -R nosplash -R nojvm '...
   ' ' include_string ' '...
   ' ' source_file ';']) 
%% copy files in for funsies 
cp_cmd = sprintf('cp %s %s %s',source_file,strjoin(include_files,' '),compile_dir);
system(cp_cmd);
%% unpack mcr
[~,n,~]=fileparts(source_filename);
first_run_cmd = fullfile(compile_dir ,['/run_' n '.sh ' ]);
first_run_cmd = [first_run_cmd matlab_path];
system(first_run_cmd);
%% fix permissions
permission_fix_cmds = { ...
    sprintf('find %s -type f -exec chmod a+r {} \\; ',compile_dir)
    sprintf('find %s -type f -exec chmod g+w {} \\; ',compile_dir)
    sprintf('find %s -type d -exec chmod a+rx {} \\; ',compile_dir)
    };
[s,r]=system(strjoin(permission_fix_cmds,';'));
if s
    disp(r);
end
%% link to latest
latest_path_link = fullfile(this_exec_base_dir,'latest');
if exist(latest_path_link,'dir')
    rm_ln_cmd = sprintf('rm %s',latest_path_link);
    system(rm_ln_cmd)
end
ln_cmd = sprintf('ln -s %s %s',compile_dir,latest_path_link);
system(ln_cmd);