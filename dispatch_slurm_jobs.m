function [ jobs, msg_out, msg_backup ] = dispatch_slurm_jobs( batch_file, slurm_options_string, dep_jobs, dep_type )
% Custom handling of using the sbatch command
% dep_jobs is supposed to be a : separated list of jobs
% dep type is one of slurms dependecny types OR a special -or variant which
% will allow any of the dependencies to satisfy the start criteria.
%
% internally that means use ? separator with slurm
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

if ~exist('slurm_options_string','var')
    slurm_options_string='';
end
if ~exist('dep_jobs','var')
  dep_jobs='';
end
if ~exist('dep_type','var')
dep_type='';
end

dependencies='';
dependency_string = '';
or_flag = 0;
old_slurm = 0;

if exist(batch_file,'file') % batch_file could just be a naked command
    [default_dir,t_n,t_e]=fileparts(batch_file);
    batch_file_name=[t_n,t_e];
    %%% DIRTY RESERVATION PATCH DUE TO ENV OVERRIDEING CONTENTS OF
    %%% BATCH FILE.
    % only do this if we have an sbatch file, and there is no reservation
    % string in the current dispatch to minimize collateral damage.
    %if isempty(regexpi(slurm_options_string,'.*reservation.*'))
    if ~reg_match(slurm_options_string,'.*reservation.*')
        fid = fopen(batch_file);
        batch_lines = textscan(fid, '%s', 'Delimiter', '\n');
        fclose(fid);
        % unwrap cell into cell of lines
        if numel(batch_lines)==1&&iscell(batch_lines{1})
            batch_lines=batch_lines{1}; end
        res_match='.*(--reservation.*)';
        res_idx = ~cellfun(@isempty,regexp(batch_lines,res_match));
        assert(sum(res_idx)<=1,'error handling reservation bits from sbatch file');
        if sum(res_idx)
            opt=regexp(batch_lines{res_idx},res_match,'tokens');
            opt=char(string(opt));
            %[s,opt]=system(sprintf('sed -rn ''s/.*(--reservation.*)/\\1/p'' %s',batch_file));
            %if s==0
            slurm_options_string=[slurm_options_string ' ' strtrim(opt)];
            %end
        end
        clear fid res_match res_idx opt;
    end
    %%%
    %%%
end

if reg_match(dep_type,'-or')
    [~,s_version]=system('scontrol version');
    if reg_match(s_version,'slurm 2.5.7')
        old_slurm=1;
    end
    clear s_version;
    %dep_type((end-2):end) = [];
    dep_type=strrep(dep_type,'-or','');
    or_flag = 1;
end

jobs={};
if ~isempty(dep_jobs)
    % input is expected to NOT be fully slurm compliant
    % it should be at most 1 deptype, and a list of jobs, OR a list of jobs and separate type.
    % the list is either comma or colon separated.
    dep_spec=strsplit(dep_jobs,{',',':'});
    dep_test=str2double(dep_spec{1});
    if ~isnumeric(dep_test) || isnan(dep_test)
        % if the first thing is a string, it must be the dependency type.
        % lets make sure we've only got one dep type
        assert(isempty(dep_type),' mutliple dependency types found!');
        dep_type = dep_spec{1};
        jobs=dep_spec(2:end);
    else
        if isempty(dep_type) 
            dep_type='afterok';
        end
        jobs=dep_spec;
    end
    dependency_string = strjoin([{dep_type},jobs],':');
    clear dep_spec;
else
    % singletons slip in here.
    dependency_string = dep_type;
end

if numel(jobs) && or_flag
    % next process will run if at least 1 depenency exits cleanly
    if ~old_slurm
        %{
        dep_array = strsplit(dependency_string,':');
        d_type = dep_array{1};
        d_limiter = ['?' d_type ':'];
        dep_array(1)=[];
        dep_array{1}=[d_type ':' dep_array{1}];
        dependency_string = strjoin(dep_array,d_limiter);
        %}
        dependency_string=sprintf('%s:%s',dep_type, strjoin(jobs,sprintf('?%s:',dep_type)));
    else
        dependency_string = strrep(dependency_string,dep_type,'afterany');
        error('untested');
   end
end
if ~isempty(dependency_string)
   dependencies = ['--dependency=' dependency_string]; 
end

default_slurm_out_name = 'slurm-%j.out';
default_slurm_out = fullfile(default_dir,default_slurm_out_name);
opt = sprintf(' --out=%s ',default_slurm_out);
if exist(batch_file,'file') % batch_file could just be a naked command
    if ~reg_match(slurm_options_string,'--out')
        %out_test_array = strsplit(slurm_options_string,'--out');
        %out_test = 2 - length(out_test_array);
        %if out_test % no --out specified, use directory of batch file
        slurm_options_string=[slurm_options_string opt];
    end
end

%['sbatch --requeue --mem=' mem ' -s -p ' queue ' ' slurm_options ' ' setup_dependency ' --job-name=' job_name ' --out=' batch_folder 'slurm-%j.out ' batch_file];
sbatch_cmd = sprintf('sbatch %s %s %s',slurm_options_string,dependencies,batch_file);

% SLOPADASHERY insert sbatch_cmd to our sbatch file :D
fid = fopen(batch_file, 'a+');
fprintf(fid, '\n# %s\n', sbatch_cmd);
fclose(fid);
%% schedule and capture job id
[sbatch_status,msg]=system(sbatch_cmd);
if sbatch_status~=0 
    warning('PROBLEM Scheduling with command %s output:%s ',sbatch_cmd,msg);
end
msg_string = strsplit(msg,' ');
jobid=strtrim(msg_string{end});
c_jobid={};
if ~isnan(str2double(jobid))
    c_jobid={jobid};
end
msg_out=msg;
%msg1=msg;
%disp(msg)

enable_backup_jobs=0;
%if ~isempty(str2num(jobid)) 
if numel(c_jobid)
    % if successfully scheduled add jobid to name (and maybe schedule backup)
    cmd='cp -p ';
    if ~enable_backup_jobs
        cmd='mv ';
    end
    if exist(batch_file,'file')
        % copy(or move) original sbatch file to jobid_filename.bash
        rename_sbatch_cmd = sprintf('%s %s %s',cmd, batch_file, fullfile(default_dir, sprintf('%s_%s',jobid,batch_file_name))); % changed 'mv' to 'cp'
        system(rename_sbatch_cmd);
    end
    if enable_backup_jobs
        %% Code for creating backup jobs in case originals fail. 25 May 2017, BJA
        dependencies = sprintf(' --dependency=afternotok:%s', c_jobid{1});
        sbatch_cmd =  sprintf('sbatch %s %s %s',slurm_options_string,dependencies,batch_file);
        [sbatch_status,msg]=system(sbatch_cmd);
        if sbatch_status~=0
            warning('PROBLEM Scheduling with command %s output:%s ',sbatch_cmd,msg);
        end
        msg_string = strsplit(msg,' ');
        jobid = strtrim(msg_string{end});
        msg_backup=msg;
        %disp(msg)
        if ~isnan(str2double(jobid))
            c_jobid={jobid};
        end
        %if   ~isempty(str2num(jobid_bu))
        if numel(c_jobid)==2
            cmd='mv'
            rename_sbatch_cmd = sprintf('%s %s %s',cmd, batch_file, fullfile(default_dir, sprintf('%s_backup_%s',jobid,batch_file_name)));
            system(rename_sbatch_cmd);
        end
    end
end
if ~exist('msg_backup','var')
    msg_backup='';
end
jobs=strjoin(c_jobid,':');
if ~numel(jobs)
    jobs=0;
end
end

