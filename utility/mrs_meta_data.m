function headfile=mrs_meta_data(mrd_file,img_headfile_path)
% put all of our metadata together in one headfile in a reasonable order.


%% Temporarily save_vol_data_headfile here eventually, this'll
% be take care of ahead of time by volume setup.

[p,fid_name]=fileparts(mrd_file);
data_headfile=fullfile(p,[fid_name,'.headfile']);
meta_file = fullfile(p,sprintf('%s_meta.txt',fid_name));
assert(exist(meta_file,"file"),'Cannot open %s. Forgot to transfer your meta data.',meta_file);


%the_scanner = scanner('grumpy');
[~,hdr]=load_acq_hdr('mrsolutions',mrd_file);
mrs2headfile(data_headfile,hdr,'mrd_');
meta_hf=read_headfile(meta_file,1);
%% combine different meta data bits here
% load incoming scanner data-file aux meta data.


%{
meta_hf=read_headfile(fid_headfile,1,meta_hf);
% load up the imagedata hf
[p,n]=fileparts(img_headfile_path);
headfile_bak=fullfile(p,[n '.bak']);
if ~exist(headfile_bak,'file')
    image_hf=read_headfile(img_headfile_path,1);
else
    image_hf=read_headfile(headfile_bak,1);
end
%}
%% build the full hf
% initializes as image_hf to set the order of fields, this is then added
% again later to ensure the image_hf values take priority.
%headfile=image_hf;
%headfile=combine_struct(headfile,meta_hf);
headfile = meta_hf;
%headfile=combine_struct(headfile,image_hf);
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
% if ~exist(headfile_bak,'file')
%     movefile(img_headfile_path,headfile_bak);
% end
if ~isfield(headfile,'F_imgformat')
    % Preliminary data patch
    warning('Missing expected parameter F_imgformat, insterting with valu eof raw');
    headfile.F_imgformat='raw';
end
% write_headfile(img_headfile_path,headfile,'',0)
