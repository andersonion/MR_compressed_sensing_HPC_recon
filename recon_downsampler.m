function recon_downsampler(cs_runno,runno_downsample,vol_lim)
% resample's a CS recon tmp file into multiple outputs.
%     fractional dowsamples should work if desired. 
%     All downsampling is uniform.(if your data is isotropic, the output will be as well).
%
% inputs are the 
% cs_runno - the input base runnumber eg, N1234
% runno_downsample - a structure of output runnos, whos value is the downample amount, (a positive value > 1 ) 
%               ex runno_downsample.N1235=2;% creates 2x downsample
%                  runno_downsample.N1236=3;% creates 3x downsample
%                  runno_downsample.N1237=1.5;% creates 1.5x downsample
% vol_lim - limit to how many volumes we'll process(optional)
%
% Ex. create 2x, 3x, and 8x 
% cs_runno='N50000';
% runno_downsample=struct; % will use a structure to record what we've done.
% need to insert the downsampling to the output by runno
% runno_downsample.N40002=2;   % example 1/2
% runno_downsample.N40003=3;   % example 1/3
% runno_downsample.N40008=8;   % example 1/8
% recon_downsampler(cs_runno,runno_downsample);
%
%
if ~exist('vol_lim','var')
    vol_lim=inf;
end
work_folder=fullfile(getenv('BIGGUS_DISKUS'),sprintf('%s.work',cs_runno));
[s_out,vol_dirs]=system(sprintf('ls -d %s/*_m*/',work_folder));
vol_dirs=strsplit(strtrim(vol_dirs));
rx_out=fieldnames(runno_downsample);
fprintf(' found %i volumes which will be downsampled into %i volumes each, for a total of %i\n',...
    numel(vol_dirs),numel(rx_out),numel(vol_dirs)*numel(rx_out));
for idx_vd=1:numel(vol_dirs)
    if idx_vd>vol_lim
        break;
    end
    % this'll pull the volume runno off the volume dir so we can find the
    % setup variables. 
    [~,vol_runno]=fileparts(fileparts(vol_dirs{idx_vd}));
    t_regout=regexp(vol_runno,sprintf('%s(_m[0-9]+)',cs_runno),'tokens');
    vol_mth=t_regout{1}{1};
    setup_file=fullfile(vol_dirs{idx_vd},sprintf('%s_setup_variables.mat',vol_runno));
    input_mat=matfile(setup_file);
    for rn=1:numel(rx_out)
        %% copy and update the output_setup file.
        out_setup=strrep(setup_file,cs_runno,rx_out{rn});
        vol_dir_out=fileparts(out_setup);
        if ~exist(vol_dir_out,'dir')
            [s,sout]=system(sprintf('mkdir -p %s',vol_dir_out));
            if s~=0
                error(sout);
            end
        end
        if ~exist(out_setup,'file')
            system(sprintf('cp -pn %s %s',setup_file,out_setup));
        end
        out_mat=matfile(out_setup,'Writable',true);
        div=runno_downsample.(rx_out{rn});
        % adjust dimensions
        db=input_mat.databuffer;
        out_dims=[db.headfile.dim_X/div db.headfile.dim_Y/div db.headfile.dim_Z/div];
        db.headfile.dim_X=round(out_dims(1));
        db.headfile.dim_Y=round(out_dims(2));
        db.headfile.dim_Z=round(out_dims(3));
        db.headfile.U_runno=sprintf('%s%s',rx_out{rn},vol_mth);
        out_mat.databuffer=db;
        % have to adjust databuffer not the plain vars.
        % adjust output paths and vars
        out_mat.runno=rx_out{rn};
        out_mat.images_dir=strrep(out_mat.images_dir,cs_runno,rx_out{rn});
        out_mat.log_file=strrep(out_mat.log_file,cs_runno,rx_out{rn});
        % OLD scale file format is RUNNO_4D_scaling_factor.float.
        % we need to create it with a content of 1 to prevent problems.
        out_mat.scale_file=strrep(input_mat.scale_file,cs_runno,rx_out{rn});
        % new scalefile will be .RUNNO_civm_raw_scale.float
        % we cant just use the new scale file because the volume-cleanup code would apply that twice *sigh*.
        %[sp,sn,se]=fileparts(out_mat.scale_file);
        %out_mat.scale_file=fullfile(sp,sprintf('.%s_civm_raw_scale.float',rx_out{rn}));
        if ~exist(out_mat.scale_file,'file')
          fid_sc = fopen(out_mat.scale_file,'w');
          % scale write count
          sc_wc = fwrite(fid_sc,1,'float');
          fclose(fid_sc);
        end

        
        out_mat.volume_log_file=strrep(out_mat.volume_log_file,cs_runno,rx_out{rn});
        out_mat.volume_runno=db.headfile.U_runno;
        % run volume_cleanup with new outputsize
        % check for completion
        if exist(fullfile(vol_dir_out,'.ds_complete'),'file')
            continue;
        end
        cleanup_errors=volume_cleanup_for_CSrecon_exec(out_setup,out_dims)
        % if status good 
        % note, cleanup doesnt actually do error handling at the time of this writing :(
        if ~cleanup_errors
          system(sprintf('echo %ix > %s/%s',div,vol_dir_out,'.ds_complete'))
        end
    end
end
