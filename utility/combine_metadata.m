function headfile=combine_metadata(setup_variables,varargin)
% put all of our metadata together in one headfile in a reasonable order.

setup_var=matfile(setup_variables);
% setup_var.headfile_path

recon_mat=matfile(setup_var.recon_file);
the_scanner=recon_mat.the_scanner;

meta_data_cells=varargin;
if  numel(meta_data_cells)==1 && iscell(meta_data_cells{1})
    meta_data_cells=meta_data_cells{1};
end

%% meta data grab 
% clean meta-data definitions and try metadata fetch, 
% 
% dont concern ourselves if we fail.
%
% Includes handling multi-input, will not replace existing files.
% volume_index has its own special fetch elsewhere becuase of that.
% Also, this'll fetch a per volume copy of volume index, not in the volume
% shared location.
t_meta=tic;
for i_m=1:numel(meta_data_cells)
    meta_file=meta_data_cells{i_m};
    %{
                m_dir=recon_mat.study_workdir;
                if ~single_data_file && reg_match(meta_file,'<FID_NAME>')
                    % per-fid meta data goes into volume_dir, others are stored at
                    % main level.
                    m_dir=volume_dir;
                end
    %}
    % have decided that we will always drag to volume_dir, this
    % will generate a replicate of volume_index. We're doing
    % this to avoid a puller collision.
    m_dir=setup_var.volume_dir;
    [~,temp_n,~]=fileparts(setup_var.volume_fid);
    meta_file=strrep(meta_file,'<FID_NAME>',temp_n);
    meta_file=path_convert_platform(meta_file,'lin');
    % [~,meta_name,meta_ext]=fileparts(meta_file);
    pull_cmd=sprintf('puller_simple -oer -f file -u %s %s ''%s'' ''%s''',...
        the_scanner.user, the_scanner.name, ...
        meta_file, ...
        path_convert_platform(m_dir,'lin') );
    %fullfile(path_convert_platform(m_dir,'lin'),[meta_name,meta_ext])  );
    [s,sout] = system(pull_cmd);
    if s~=0; fprintf('%s\n',sout); end
    [~,meta_name,meta_ext]=fileparts(meta_file);
    meta_data_cells{i_m}=fullfile(m_dir,[meta_name, meta_ext]);
end
meta_resolve_time=toc(t_meta);
log_msg=sprintf('meta resolve time %s\n',time_struct(meta_resolve_time).string());
fprintf(log_msg);
% yet_another_logger(log_msg,log_mode,log_file);
%% Temporarily save_vol_data_headfile here eventually, this'll
% be take care of ahead of time by volume setup.
fid_headfile=save_vol_data_headfile(setup_variables);
%% combine different meta data bits here
% load incoming scanner data-file aux meta data.
if reg_match(the_scanner.vendor,'mrsolutions')
    % this only covers our specially dumped meta data.
    hf_prefix='';
    i = find(contains(meta_data_cells,'meta.txt'));
elseif reg_match(the_scanner.vendor,'agilent')
    db_inplace(mfilename,'first time with new recon for agilent data');
    warning('untested');
    i = find(contains(meta_data_cells,'procpar'));
    hf_prefix='z_Agilent_';
    if numel(i) && exist(meta_data_cells{i},'file')
        p_dir=fileparts(meta_data_cells{i});
        a_file = fullfile(p_dir,'agilent.headfile');
        dump_cmd = sprintf('dumpHeader -d0 -o %s %s',the_scanner.name,p_dir);
        [s,sout]=system(dump_cmd);assert(s==0,sout);
        meta_data_cells{i}=a_file;
    end
else
    error('unrecognized vendor: %s',the_scanner.vendor);
end
if numel(i) && exist(meta_data_cells{i},'file')
    % acquisition auxilliary metadata
    meta_hf=read_headfile(meta_data_cells{i},1);
    if ~isempty(hf_prefix)
        meta_hf=combine_struct(struct,meta_hf,hf_prefix);
    end
end
meta_hf=read_headfile(fid_headfile,1,meta_hf);
% load up the imagedata hf
[~,n]=fileparts(setup_var.headfile_path);
headfile_bak=fullfile(setup_var.volume_dir,[n '.bak']);
if ~exist(headfile_bak,'file')
    image_hf=read_headfile(setup_var.headfile_path,1);
else
    image_hf=read_headfile(headfile_bak,1);
end
%% build the full hf
% initializes as image_hf to set the order of fields, this is then added
% again later to ensure the image_hf values take priority.
headfile=image_hf;
headfile=combine_struct(headfile,meta_hf);
headfile=combine_struct(headfile,image_hf);
% add the classic headfile fields if they're missing
field_transcriber.fovx={'fov_read',1e3};
field_transcriber.fovy={'fov_phase',1e3};
field_transcriber.fovz={'fov_slice',1e3};
field_transcriber.te={'echo_time',1e3};
field_transcriber.tr={'rep_time',1e6};
field_transcriber.S_PSDname={'acq_Sequence',''};
field_transcriber.alpha={'flip',1};
field_transcriber.bw={'bandwidth',1/2};
field_transcriber.ne={'ppr_no_echoes',1};
fields=fieldnames(field_transcriber);
%field_transcriber.={'',}
for i=1:numel(fields)
    %field out
    f_o=fields{i};
    % field in
    f_i=field_transcriber.(f_o){1};
    % field mul
    f_m=field_transcriber.(f_o){2};
    if ~isfield(headfile,f_i)
        warning('missing %s, cant transcribe to %s',f_i,f_o);
        continue;
    end
    if ~ischar(f_m)
        headfile.(f_o)=headfile.(f_i)*f_m;
    else
        headfile.(f_o)=headfile.(f_i);
    end
end
if ~exist(headfile_bak,'file')
    movefile(setup_var.headfile_path,headfile_bak);
end
if ~isfield(headfile,'F_imgformat')
    % Preliminary data patch
    warning('Missing expected parameter F_imgformat, insterting with valu eof raw');
    headfile.F_imgformat='raw';
end
write_headfile(setup_var.headfile_path,headfile,'',0)
