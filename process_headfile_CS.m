function process_headfile_CS(reconmat_file,partial_headfile,procpar_path,recon_type )

%{
if exist('procpar_path','var')

    [~,pp_name,pp_ext] = fileparts(procpar_path);
    procpar_for_archive = [voldir '/' pp_name pp_ext];

    if ~exist(procpar_for_archive,'file')
        cp_cmd = ['cp ' procpar_path ' ' voldir '/'];
        system(cp_cmd);
     end
end
%}
%% Make and save header data
%procpar = readprocparCS(procpar_path);
load(reconmat_file);

% DTI volume-specific header data
partial_info = read_headfile(partial_headfile,true);
if exist(procpar_path,'file')
    [p,~,~]=fileparts(procpar_path);
    if ~exist(fullfile(p,'procpar'),'file')
        cmd = sprintf('ln -s %s %s/procpar',procpar_path,p);
        system(cmd);
    end
    a_file = sprintf('%s/agilent.headfile',p);
    if ~exist(a_file,'file') 
        dump_cmd = sprintf('dumpHeader -o %s %s',partial_info.U_scanner,p);
        system(dump_cmd)
    else
        size_test_cmd = sprintf('wc -c %s | cut -d '' '' -f1',a_file);
        [~,size_test]=system(size_test_cmd);
        if ~size_test
        	dump_cmd = sprintf('dumpHeader -o %s %s',partial_info.U_scanner,p);
            system(dump_cmd)
        end
    end
        
    procpar = read_headfile(a_file,true);
    output_headfile = combine_struct(procpar,partial_info);
    %output_headfile.state = output_headfile.U_state;
    %output_headfile.bw = procpar.sw/2;
        
    if ~exist('recon_type','var')
        recon_type = 'cluster_matlab';
    end
    output_headfile.B_recon_type = recon_type;
    
    output_headfile.U_stored_file_format = 'raw';
    
    output_headfile.CS_TVWeight = TVWeight;
    output_headfile.CS_xfmWeight = xfmWeight;
    output_headfile.CS_Itnlim = Itnlim;
    output_headfile.CS_OuterIt = OuterIt;
    
    %{
        output_headfile.S_PSDname = char(procpar.seqfil);
        output_headfile.S_scanner_tag = 'A_';
        output_headfile.S_tag = 'A_';
        output_headfile.S_tesla = output_headfile.scanner_tesla_image_code;
        output_headfile.alpha = procpar.flip1;

        output_headfile.fovx = fov(1);
        output_headfile.fovy = fov(2);
        output_headfile.fovz = fov(3);
        output_headfile.hfpmcnt = 1; % not sure where this comes from or if it needs to change
        output_headfile.matlab_functioncall = 'enter_later'; % enter this later
        output_headfile.ne = nechoes;
        output_headfile.scanner_vendor = 'agilent';
        output_headfile.te = procpar.te*1e3;
        output_headfile.tr = procpar.tr*1e6;
    %}
    
    %output_headfile.work_dir_path = ['/' target_machine 'space/' runno '.work'];
    output_headfile.CS_sampling_fraction = sampling_fraction;
    output_headfile.CS_acceleration = 1/sampling_fraction;
    
    if exist(scale_file,'file')
        fid_sc = fopen(scale_file,'r');
        scaling = fread(fid_sc,inf,'*float');
        fclose(fid_sc);
        output_headfile.group_image_scale = scaling;
    end
    
    % While this is called "partial" it is now complete
    write_headfile(partial_headfile,output_headfile,'',0);
else
    
    disp('Failed to process headfile!');
end
end

