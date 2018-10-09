function misguided_status_code = volume_cleanup_for_CSrecon_exec(volume_variable_file)
%%  This an updated version of implied version 1, but with the second version of architecture
%   Expected changes include: complex single-precision data stored in the
%   tmp file instead of double-precision magnitude images.
%   Decentralized scaling is now handled here instead of during setup
%a
% 16 May 2017, BJA: qsm_fermi_filter option is added (default 0) in case we
% do need the complex data written out a la QSM processing, and decide that
% we do want the fermi_filtered data instead of the unfiltered data. It is
% assumed that the QSM requires unfiltered data.  Bake it in now will not
% require recompilation later if we need this option.
misguided_status_code = 0;
if ~isdeployed && (~exist('volume_variable_file','var') || isempty(volume_variable_file) )
    volume_variable_file = '/nas4/bj/S67950_02.work/S67950_02_m1/work/S67950_02_m1_setup_variables.mat';
    %volume_scale = 1.4493;
    %variable_iterations=1;
    addpath('/cm/shared/workstation_code_dev/recon/CS_v2/CS_utilities/');
    addpath('/cm/shared/workstation_code_dev/recon/WavelabMex/');
else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end

% TEMPORARY CODE for backwards compatibility of in-progress scans remove by
% June 12th, 2018
if ~exist(volume_variable_file,'file')
    [t_workdir, t_file_name, t_ext]=fileparts(volume_variable_file);
    old_vv_file = [t_workdir '/work/' t_file_name t_ext];
    mv_cmd = ['mv ' old_vv_file ' ' volume_variable_file];
    if exist(old_vv_file,'file')
        system(mv_cmd);
    end
end
load(volume_variable_file);
%recon_dims(1)=6;
%original_dims(1)=6;
%scale_file=aux_param2.scaleFile;
%% foggy loggy doggy 
if ~exist('log_mode','var')
    log_mode = 1;
end
log_files = {};
if exist('volume_log_file','var')
    log_files{end+1}=volume_log_file;
end
if exist('log_file','var')
    log_files{end+1}=log_file;
end
if (numel(log_files) > 0)
    log_file = strjoin(log_files,',');
else
    log_file = '';
    log_mode = 3;
end

%%
if ~exist('continue_recon_enabled','var')
    continue_recon_enabled=1;
end
if ~exist('variable_iterations','var')
    variable_iterations=0;
end
%% get scaling file or show error
scale_file_error =1;
if exist('scale_file','var')
    num_checks = 30;
    for tt = 1:num_checks
        %disp(['tt = ' num2str(tt)])
        if exist(scale_file,'file')
            scale_file_error = 0;
            break;
        else
            pause(1)
        end
    end
end
if ~scale_file_error
    fid_sc = fopen(scale_file,'r');
    scaling = fread(fid_sc,inf,'*float');
    fclose(fid_sc);
else
    error_flag = 1;
    log_msg =sprintf('Volume %s: cannot find scale file: (%s); DYING.\n',volume_runno,scale_file);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    status=variable_to_force_an_error;
    quit force
end

%% get options into base workspace.
if ~exist('recon_dims','var')
    recon_dims = original_dims;
elseif  ~exist('original_dims','var')
    original_dims = recon_dims;
end
if ~exist('fermi_filter','var')
    fermi_filter = 1;
end
if exist('fermi_filter_w1','var')
    w1=fermi_filter_w1;
else
    w1 = 0.15;
end
if exist('fermi_filter_w2','var')
    w2=fermi_filter_w2;
else
    w2 = 0.75;
end
if ~exist('write_qsm','var')
    write_qsm=0;
end
if ~exist('qsm_fermi_filter','var')
    qsm_fermi_filter=0;
end
%%
if continue_recon_enabled % This should be made default.
    if ~exist('wavelet_dims','var')
        if exist('waveletDims','var')
            wavelet_dims = waveletDims;
        else
            wavelet_dims = [12 12];
        end
    end
    if ~exist('wavelet_type','var')
        wavelet_type = 'Daubechies';
    end
    XFM = Wavelet(wavelet_type,wavelet_dims(1),wavelet_dims(2));
end

%% check on temp file, try to get amount complete, or exit on fail
temp_file_error = 1;
if exist('temp_file','var')
    num_checks = 30;
    for tt = 1:num_checks
        if exist(temp_file,'file')
            temp_file_error = 0;
            break;
        else
            pause(1)
        end
    end
end
error_flag=0;
if temp_file_error
    error_flag=1;
    if ~exist('temp_file','var')
        log_msg =sprintf('Volume %s: Cannot find name of temporary file in variables file: %s; DYING.\n',volume_runno,volume_variable_file);
    else
        log_msg =sprintf('Volume %s: Cannot find temporary file: %s; DYING.\n',volume_runno,temp_file);
    end
else
    [~,number_of_at_least_partially_reconned_slices,tmp_header] = read_header_of_CStmp_file(temp_file);
    unreconned_slices = length(find(~tmp_header));
    if (continue_recon_enabled && ~variable_iterations)
        unreconned_slices = length(find(tmp_header<options.Itnlim));
    end
    if  (unreconned_slices > 0)
        error_flag=1;
        log_msg =sprintf('Volume %s: %i slices appear to be inadequately reconstructed; DYING.\n',volume_runno,unreconned_slices);
    else
        log_msg =sprintf('Volume %s: All %i slices appear to be reconstructed; cleaning up volume now.\n',volume_runno,number_of_at_least_partially_reconned_slices);
    end
end
yet_another_logger(log_msg,log_mode,log_file,error_flag);
if error_flag==1
    status=variable_to_force_an_error;
    quit force
end

%% Read in temporary data
log_msg =sprintf('Volume %s: Reading data from temporary file: %s...\n',volume_runno,temp_file);
yet_another_logger(log_msg,log_mode,log_file);
tic
fid=fopen(temp_file,'r');
%fseek(fid,header_size*64,-1);
header_size = fread(fid,1,'uint16');
fseek(fid,2*header_size,0);
%data_in=fread(fid,inf,'*uint8');
minimal_memory=getenv('CS_minimize_memory');
if isempty(minimal_memory)
    %minimal_memory=0;
    minimal_memory=1; % Flipping the default switch on 5 January 2018
end
BRIGHT_NOISE_THRESHOLD=0.9995; % our magic number threshold to remove bright noise.
if minimal_memory
    %% min memory mode, we only load 1 full CS slice at a time, 
    % each is reduced to the proscribed acq dim 
    % and inserted into a full size acq vol before moving on to the next.
    % Potentially we could do better using a  sparse load but thats a lot of
    % work.
    already_fermi_filtered=0;
    log_msg =sprintf('%s operating in minimal memory mode',mfilename);
    yet_another_logger(log_msg,log_mode,log_file);
    lil_dummy = zeros([1,1],'double');
    lil_dummy = complex(lil_dummy,lil_dummy);
    data_out=zeros(original_dims,'like',lil_dummy);
    bytes_per_slice=2*8*recon_dims(2)*recon_dims(3);
    % Slice quantiles are not exactly the right answer, so that whole idea
    % has been scrapped in favor of the old (silly?) sorted array pct, and
    % its done at the end when we take the magnitude.
    % slice_quantile=zeros(1,recon_dims(1));
    for ss=1:recon_dims(1)
        if ~mod(ss,10)
            log_msg = sprintf('Processing slice %i...\n',ss);
            yet_another_logger(log_msg,log_mode,log_file);
        end
        % James says: This data read is a bit strange, 
        % why dont we just read in as double direct?
        % BJ responds: We made this decision together; it
        % is more robust this way, as we were running into
        % issues otherwise (bigendian/littleendian or something
        % like that).
        data_in = typecast(fread(fid,bytes_per_slice,'*uint8'),'double');
        data_in = reshape(data_in, [recon_dims(2) recon_dims(3) 2]);
        % t is temp data, as in from the temporary file, truly, its our
        % final product of iterations to be written after the final
        % waveletting stuff.
        t_data_out=complex(squeeze(data_in(:,:,1,:)),squeeze(data_in(:,:,2,:)));
        clear data_in;
        t_data_out = XFM'*t_data_out;
        t_data_out = t_data_out*volume_scale/sqrt(recon_dims(2)*recon_dims(3));
        %% Crop out extra k-space if non-square or non-power of 2, 
        % might as well apply fermi filter in k-space, if requested (no QSM requested either)
        if sum(original_dims == recon_dims) ~= 3
            t_data_out = fftshift(fftn(fftshift(t_data_out)));
            final_slice_out = t_data_out((recon_dims(2)-original_dims(2))/2+1:end-(recon_dims(2)-original_dims(2))/2, ...
                (recon_dims(3)-original_dims(3))/2+1:end-(recon_dims(3)-original_dims(3))/2);
            final_slice_out = fftshift(ifftn(fftshift(final_slice_out)));
        else
            final_slice_out=t_data_out;
        end
        final_slice_out=scaling*final_slice_out;
        % slice quantiles added to set final image scaling before
        % write_civm_image. This is not a great bit of code because it
        % needs to operate on magnitude data, and has to do an abs in line
        % here.
        % On review of quantile operations, this is not okay, nor is it
        % okay enough to use. 
        % slice_quantile(s)=quantile(abs(final_slice_out),BRIGHT_NOISE_THRESHOLD);
        data_out(ss,:,:)= final_slice_out;
    end
    read_time = toc;
    log_msg =sprintf('Volume %s: Done reading in temporary data and slice-wise post-processing; Total elapsed time: %0.2f seconds.\n',volume_runno,read_time);
    yet_another_logger(log_msg,log_mode,log_file);
else
    if ~continue_recon_enabled
        data_in=typecast(fread(fid,inf,'*uint8'),'single');
        %data_in=typecast(fread(fid,2*dims(1)*dims(2)*dims(3),'*uint8'),'single');
    else
        %data_in=fread(fid,inf,'*double');
        data_in=typecast(fread(fid,inf,'*uint8'),'double');
    end
    
    read_time = toc;
    log_msg =sprintf('Volume %s: Done reading in temporary data; Total elapsed time: %0.2f seconds.\n',volume_runno,read_time);
    yet_another_logger(log_msg,log_mode,log_file);
    tic
    already_fermi_filtered = 0;
    if ~continue_recon_enabled
        data_out=scaling*complex(data_in(1:2:end),data_in(2:2:end));
        clear data_in;
        %% Reshape
        final_size=[original_dims(2),original_dims(3),original_dims(1)];
        data_out=reshape(data_out,final_size);
    else
        data_in = reshape(data_in, [recon_dims(2) recon_dims(3) 2 recon_dims(1)]);
        c_data_out=complex(squeeze(data_in(:,:,1,:)),squeeze(data_in(:,:,2,:)));
        clear data_in;
        for ss=1:recon_dims(1)
            c_data_out(:,:,ss) = XFM'*c_data_out(:,:,ss);
        end
        c_data_out = c_data_out*volume_scale/sqrt(recon_dims(2)*recon_dims(3));
        %% Crop out extra k-space if non-square or non-power of 2, might as well apply fermi filter in k-space, if requested (no QSM requested either)
        if sum(original_dims == recon_dims) ~= 3
            c_data_out = fftshift(fftn(fftshift(c_data_out)));
            data_out = c_data_out((recon_dims(2)-original_dims(2))/2+1:end-(recon_dims(2)-original_dims(2))/2, ...
                (recon_dims(3)-original_dims(3))/2+1:end-(recon_dims(3)-original_dims(3))/2,:);
            clear c_data_out
            if (fermi_filter && ~qsm_fermi_filter)
                % this check for fermi vars is unnecessary, we always make sure w1
                % and w2 are set.
                %if exist('w1','var')
                    data_out = fermi_filter_isodim2_memfix(data_out,w1,w2);
                %else
                %    data_out= fermi_filter_isodim2_memfix(data_out);
                %end
                already_fermi_filtered = 1;
            end
            data_out = fftshift(ifftn(fftshift(data_out)));
        else
            data_out=c_data_out;
            clear c_data_out;
        end
        data_out= scaling*data_out;
    end
    post_proc_time=toc;
    log_msg =sprintf('Volume %s: Done post-processing reconstructed data; Total elapsed time: %0.2f seconds.\n',volume_runno,post_proc_time);
    yet_another_logger(log_msg,log_mode,log_file);
    % Permute to final form
    data_out = permute(data_out,[3 1 2 4]);
end %?
fclose(fid);

%% Save complex data for QSM BEFORE the possibility of a fermi filter being
% applied.
if write_qsm
    qsm_folder = [workdir '/qsm/'];
    if ~exist(qsm_folder,'dir')
        system(['mkdir -m 777 ' qsm_folder]);
    end
    qsm_file = [qsm_folder volume_runno '_raw_qsm.mat'];
end
if ~qsm_fermi_filter
    if write_qsm
        if ~exist(qsm_file,'file')
            tic
            if continue_recon_enabled
                real_data = single(real(data_out));
                imag_data = single(imag(data_out));
            else
                real_data = real(data_out);
                imag_data = imag(data_out);
            end
            savefast2(qsm_file,'real_data','imag_data');
            qsm_write_time = toc;
            clear real_data imag_data
            log_msg =sprintf('Volume %s: Done writing raw complex data for QSM: %s; Total elapsed time: %0.2f seconds.\n',volume_runno,qsm_file, qsm_write_time);
            yet_another_logger(log_msg,log_mode,log_file);
            %save(qsm_file,'data_out','-v7.3');
        end
    end
end

%% Apply Fermi Filter
if (fermi_filter && ~already_fermi_filtered)
    data_out = fftshift(fftn(fftshift(data_out)));
    if exist('w1','var')
        data_out = fermi_filter_isodim2_memfix(data_out,w1,w2);
    else
        data_out= fermi_filter_isodim2_memfix(data_out);
    end
    data_out =fftshift(ifftn(fftshift(data_out)));
end
%data_out = abs(data_out);
if ~isdeployed && strcmp(getenv('USER'),'rja20')
    figure(12)
    %imagesc(abs(squeeze(data_out(round(original_dims(1)/2),:,:))))
    imagesc(abs(squeeze(data_out(:,:,round(original_dims(3)/2)))))
    colormap gray
end

%% Save data
if qsm_fermi_filter
    if write_qsm
        if ~exist(qsm_file,'file')
            tic
            if continue_recon_enabled
                real_data = single(real(data_out));
                imag_data = single(imag(data_out));
            else
                real_data = real(data_out);
                imag_data = imag(data_out);
            end
            savefast2(qsm_file,'real_data','imag_data')
            qsm_write_time = toc;
            clear real_data imag_data
            
            log_msg =sprintf('Volume %s: Done writing raw complex data for QSM: %s; Total elapsed time: %0.2f seconds.\n',volume_runno,qsm_file, qsm_write_time);
            yet_another_logger(log_msg,log_mode,log_file);
            %save(qsm_file,'data_out','-v7.3');
        end
    end
end
mag_data = abs(data_out);
clear data_out;
%{
% Move to processing after the procpar file has been processed.
write_archive_tag_nodev(volume_runno,['/' target_machine 'space'],original_dims(3),struct1.U_code, ...
    ['.' struct1.U_stored_file_format],struct1.U_civmid,true,images_dir)

%}
%write_civm_image(fullfile(images_dir,[volume_runno struct1.scanner_tesla_image_code 'imx']), ...
%    mag_data,struct1.U_stored_file_format,0,1)

%% Pre 17 May 2018 code:
%{
    write_civm_image(fullfile(images_dir,[volume_runno databuffer.headfile.scanner_tesla_image_code 'imx']), ...
        mag_data,'raw',0,1)
%}
%% Post 17 May 2018 code:
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_total=tmp_header;
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_mean = mean(tmp_header(:));
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_min = min(tmp_header(:));
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_max = max(tmp_header(:));
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_std = std(tmp_header(:));
databuffer.headfile.U_runno = volume_runno;

mf=matfile(recon_file);
try
    first_corner_voxel=mf.first_corner_voxel;
    if options.roll_data
        suffix='';
    else
        suffix='_recommendation';
    end
    databuffer.headfile.(['roll_corner_X' suffix ]) = first_corner_voxel(1);
    databuffer.headfile.(['roll_corner_Y' suffix ]) = first_corner_voxel(2);
    databuffer.headfile.(['roll_first_Z' suffix ])  = first_corner_voxel(3);
catch roll_err
    disp(roll_err.message);
end

%% sloppy scale calculating at end of process.
% operating by slice doesnt give the right result (chunk wouldnt either
% for the same reasons).
% This causes a memory surge of +1 volume, as best as james can figure, that
% is unavaoidable.
% The old fashioned sort code was used instead of quantile due to
% superstition.
%{
if exist('slice_quantile','var')
    % we operated by slices, we need a "best" guess value to threshold off
    % the high pixel noise. 
    % Min would be wrong, becuase there is no guarentee of bright trash
    % voxels per slice, 
    % Max is wrong for the same reason. 
    % Mean could be correct, but feels fuzzy.
    warning('Slice quantile conversion for max value! This is known to be somewhat bogus! this is in place for evaluation! If you see this message in production notify at james/BJ Immediately!');
    data_quantile=quantile(slice_quantile,0.75);
    databuffer.headfile.slice_quantiles=slice_quantile;
else
%}
%data_quantile=quantile(data_out,BRIGHT_NOISE_THRESHOLD);
%end
% OLD scale file format is RUNNO_4D_scaling_factor.float.
% new scalefile will be .RUNNO_civm_raw_scale.float
% When we have time in the future it would be nice to have only one scale
% operation, however these are inexpensive in cpu/memory so its not so bad
% to do it twice.
final_scale_file=fullfile(fileparts(scale_file),sprintf('.%s_civm_raw_scale.float',runno));
% have to regenerate volume number because it is not kept, we're using the
% runno as a proxy. This is more brittle than I'd like however it should be
% decent.
%vnt, volume number text
vt=regexpi(volume_runno,'[^0-9]*_m([0-9]+$)','tokens');
if isempty(vt)
    warning('volume_cleanup: guess of volume number unsucessful, setting to 1, best of luck!');
    vt={'0'};
end
volume_number=1+str2double(vt{:});
scale_target=2^16-1;
databuffer.headfile.group_max_intensity=max(mag_data(:));
if volume_number==1 && ~exist(final_scale_file,'file')
    mag_s=sort(mag_data(:));
    data_quantile=mag_s(round(numel(mag_s)*BRIGHT_NOISE_THRESHOLD));
    final_scale=scale_target/data_quantile;
    clear mag_s;
    fid_sc = fopen(final_scale_file,'w');
    % scale write count
    sc_wc = fwrite(fid_sc,final_scale,'float');
    fclose(fid_sc);
    log_msg=sprintf('volume_cleanup: This is the first volume in acq, setting final image scale to %0.14f in %s.\n' ...
        ,final_scale,final_scale_file);
    databuffer.headfile.group_max_atpct=data_quantile;
else
    % load newscale
    fid_sc = fopen(final_scale_file,'r');
    final_scale = fread(fid_sc,inf,'*float');
    fclose(fid_sc);
    log_msg=sprintf('volume_cleanup: Volume %i found scale file %s, with value %0.14f.\n' ...
        ,final_scale_file,final_scale);
    databuffer.headfile.group_max_atpct=databuffer.headfile.group_max_intensity;
end
mag_data=mag_data*final_scale;
yet_another_logger(log_msg,log_mode,log_file);
databuffer.headfile.divisor=1/final_scale;% legacy just for confusion :D 
fprintf('\tMax value chosen for output scale: %0.14f\n',databuffer.headfile.group_max_atpct);

%% save civm_raw
databuffer.data = mag_data;clear mag_data; % mag_data clear probably unnecessary, this is just in case.
if ~isfield(options,'unrecognized_fields')
    options.unrecognized_fields=struct;
end
unrecog_cell={'planned_ok'};
unrecog_cell=[unrecog_cell mat_pipe_opt2cell(options.unrecognized_fields)];
write_civm_image(databuffer,[{['write_civm_raw=' images_dir],'overwrite','skip_write_archive_tag'} unrecog_cell]);
if options.live_run2
    options.keep_work=1;
end
if ~options.keep_work && ~options.process_headfiles_only
    if exist(headfile,'file') %Is this the right condition?
        if exist(work_subfolder,'dir')
            log_msg =sprintf('Images have been successfully reconstructed; removing %s now...',work_subfolder);
            yet_another_logger(log_msg,log_mode,log_file);
            rm_cmd=sprintf('rm -rf %s',work_subfolder);
            system(rm_cmd);
        else
            
            log_msg =sprintf('Work folder %s already appears to have been removed. No action will be taken.\n',work_subfolder);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    else
        log_msg =sprintf('Images have not been successfully transferred yet; work folder will not be removed at this time.\n')
        yet_another_logger(log_msg,log_mode,log_file);
    end
end
%% LEAKY PROCPAR HANDLERS FOR SOME REASON!
% its not clear why yet, but this deploy procpar handlers command leaks 
% deploy_procpar_handlers(volume_variable_file); 

end
