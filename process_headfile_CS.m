function process_headfile_CS(recon_file,image_dir_hf,procpar_path,recon_type )
% read image_dir hf and add procpar to our headfiles.
% image_dir_hf vars take prescedence
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
if ~exist('recon_type','var')
    recon_type = 'matlab_CS';
    warning('Default recon type: %s',recon_type);
end
%% avoid repetition.
BytesPerKiB=2^10;
minKiB=20;
finfo=dir(image_dir_hf);
if finfo.bytes>minKiB*BytesPerKiB
   warning('Previously added procpar to headfile, skipping');
   return;
end

%{
if exist('procpar_path','var')

    [~,pp_name,pp_ext] = fileparts(procpar_path);
    procpar_for_archive = [voldir '/' pp_name pp_ext];

    if ~exist(procpar_for_archive,'file')
        cp_cmd = ['cp -p ' procpar_path ' ' voldir '/'];
        system(cp_cmd);
     end
end
%}
%% Make and save header data
%procpar = readprocparCS(procpar_path);
% load(reconmat_file);
recon_mat=matfile(recon_file);
% options=recon_mat.options;

% DTI volume-specific header data
partial_info = read_headfile(image_dir_hf,true);
if exist(procpar_path,'file')
    %% convert procpar to headfile
    [p,~,~]=fileparts(procpar_path);
    % legacy named procpar support.
    proc_exact=fullfile(p,'procpar');
    if ~exist(proc_exact,'file')
        warning('Procpar was renamed in transfer, setting up a link');
        cmd = sprintf('ln -s %s %s',procpar_path,proc_exact);
        system(cmd);
    end
    a_file = fullfile(p,'agilent.headfile');
    procpar_convert=1;
    if exist(a_file,'file')
        minKiB=5;
        finfo=dir(a_file);
        if finfo.bytes>minKiB*BytesPerKiB
            procpar_convert=0;
        end
    end
    if procpar_convert
        dump_cmd = sprintf('dumpHeader -d0 -o %s %s',partial_info.U_scanner,p);
        [s,sout]=system(dump_cmd);
        if s~=0 
            error(sout);
        end
    end
    %% 
    procpar = read_headfile(a_file,true);
    output_headfile = combine_struct(procpar,partial_info);
    
    if ~isfield(output_headfile,'B_recon_type')
        warning('Legacy data detected, setting B_recon_type');
        output_headfile.B_recon_type = recon_type;
    end
    
    % Belongs in write_civm_image
    % Will check just in case
    if ~isfield(output_headfile,'U_stored_file_format') ... 
            && ~isfield(output_headfile,'F_imgformat')
        warning('Legacy data detected. Assuming raw output');
        output_headfile.F_imgformat='raw';
    end
    
    %output_headfile.work_dir_path = ['/' target_machine 'space/' runno '.work'];

    if exist(recon_mat.scale_file,'file')
        fid_sc = fopen(recon_mat.scale_file,'r');
        scaling = fread(fid_sc,inf,'*float');
        fclose(fid_sc);
        output_headfile.group_image_scale = scaling;
    end
    
    write_headfile(image_dir_hf,output_headfile,'',0);
else
    
    disp('Failed to process headfile!');
end
end

