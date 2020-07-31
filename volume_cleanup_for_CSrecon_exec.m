function misguided_status_code = volume_cleanup_for_CSrecon_exec(setup_variables,output_size,size_type)
% function status=VOLUME_CLEANUP_FOR_CSRECON_EXEC(volume_variable_file,output_size,size_type)
% Volume_cleanup for csrecon, reduces cs recon tmp files to final outputs through write_civm_image.
% All relevant parameters are burried inside the volume_variable file(take care!)
% output_size is optional and allows you to specify an alternate size to save the data to.
%   WARNING: this code DOES NOT update important output variables!
%   ( this code is rather sloppy in a general sense and could use some extensive cleaning. )
% size_type is unimplemented! it is aplace holder to change the type of downsizeing from voxelsize to zoom.
%  This an updated version of implied version 1, but with the second version of architecture
%   Expected changes include: complex single-precision data stored in the
%   tmp file instead of double-precision magnitude images.
%   Decentralized scaling is now handled here instead of during setup
%
% 16 May 2017, BJA: qsm_fermi_filter option is added (default 0) in case we
% do need the complex data written out a la QSM processing, and decide that
% we do want the fermi_filtered data instead of the unfiltered data. It is
% assumed that the QSM requires unfiltered data.  Bake it in now will not
% require recompilation later if we need this option.
misguided_status_code = 0;
scale_target=2^16-1;

if ~isdeployed

else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end

% load(setup_variables);
setup_var=matfile(setup_variables);
wkspc_mat=matfile(setup_var.volume_workspace);
recon_mat=matfile(setup_var.recon_file);
options=recon_mat.options;
%recon_dims(1)=6;
%original_dims(1)=6;
%scale_file=aux_param2.scaleFile;

%{
% % resolve volume_number
if ~exist('volume_number','var')
  % In the past volume_manager didnt record the volume number to our settings file.
  % So we'd have to regenerate it using the runno as a proxy. 
  % That has since been fixed, this code is left behind as for refernce.
  warning('volume_number missing, using the guess code');
  %vnt, volume number text
  vt=regexpi(setup_var.volume_runno,'[^0-9]*_m([0-9]+$)','tokens');
  if isempty(vt)
    warning('volume_cleanup: guess of volume number unsucessful, setting to 1, best of luck!');
    vt={'0'};
  end
  volume_number=1+str2double(vt{:});
end
%}
%% log details
if ~exist('log_mode','var')
    log_mode = 1;
end
log_files = {};
log_files{end+1}=setup_var.volume_log_file;
log_files{end+1}=recon_mat.log_file;
%{
if exist('volume_log_file','var')
    log_files{end+1}=volume_log_file;
end
if exist('log_file','var')
    log_files{end+1}=log_file;
end
%}
if (numel(log_files) > 0)
    log_file = strjoin(log_files,',');
else
    log_file = '';
    log_mode = 3;
end

%% pull formerly optional settings out recon_mat
%{
if ~exist('continue_recon_enabled','var')
    continue_recon_enabled=1;
end
if ~exist('variable_iterations','var')
    variable_iterations=0;
end
%}
% continue_recon is referencing that we could continue the recon, not that
% we did.
% maybe resumable_recon would be better? or since we seem to always operate
% this way, this really loses all meaning
try
    continue_recon_enabled=options.continue_recon_enabled;
catch
    warning('continue_recon_enabled not set');
    continue_recon_enabled=1;
end
try
    variable_iterations=options.variable_iterations;
catch
    warning('variable_iterations not set');
    variable_iterations=0;
end
%% get scaling file or show error
% gives us 30 x 10 second intervals to wait
% a 300 second failure extension!
% if things accidentally happen out of order this is garbage!
wait_interval=10;
num_checks = 30;
scale_file_error =1;
if setup_var.volume_number == 1 && exist(recon_mat.scale_file,'file')
    scale_file_error = 0;
elseif setup_var.volume_number ~= 1
    for tt = 1:num_checks
        if exist(recon_mat.scale_file,'file')
            scale_file_error = 0;
            break;
        else
            warning(['Waiting %i seconds for scale file, THIS IS UNFORTUNATE.\n ' ...
                '\twaited %i/%i(MAX WAIT), '],wait_interval, ...
                tt*wait_interval, wait_interval*num_checks);
            pause(wait_interval)
        end
    end
end
if ~scale_file_error
  fid_sc = fopen(recon_mat.scale_file,'r');
  scaling = fread(fid_sc,inf,'*float');
  fclose(fid_sc);
else %if (setup_var.volume_number > 1)
  error_flag = 1;
  log_msg =sprintf('Volume %s: cannot find scale file: (%s); DYING.\n',setup_var.volume_runno,recon_mat.scale_file);
  yet_another_logger(log_msg,log_mode,log_file,error_flag);
  if isdeployed
      quit force
  else
      error(log_msg);
  end
end

%% get options into base workspace.
try
    recon_dims=recon_mat.recon_dims;
catch
end
try
    original_dims=recon_mat.original_dims;
catch
end
%{
% originally allowed either or spec of recon_dims/original_dims, that is
now disabled for simpler debuggin.
if ~exist('recon_dims','var')
    recon_dims = original_dims;
elseif  ~exist('original_dims','var')
    original_dims = recon_dims;
end
%}
%{
if ~exist('fermi_filter','var')
    fermi_filter = 1;
end
%}
try
    w1=options.fermi_w1;
catch
end
%if exist('fermi_filter_w1','var')
if ~exist('w1','var')|| ~w1
    %w1=fermi_filter_w1;
%else
    warning('Fermi filter w1 not set! fermi code will use its internal default');
%    w1 = 0.15;%    w2 = 0.75;
end
%if exist('fermi_filter_w2','var')
try
    w2=options.fermi_w2;
catch
end
if ~exist('w2','var') || ~w2
%    w2=fermi_filter_w2;
%else
    warning('Fermi filter w2 not set! fermi code will use its internal default');
%    w2 = 0.75;
end
if ~exist('write_qsm','var')
    write_qsm=0;
end
if ~exist('qsm_fermi_filter','var')
    qsm_fermi_filter=0;
end

if continue_recon_enabled 
    XFM = Wavelet(options.wavelet_type,options.wavelet_dims(1),options.wavelet_dims(2));
end

%% check on temp file, try to get amount complete, or exit on fail
temp_file_error = 1;
if exist(setup_var.temp_file,'file')
    temp_file_error = 0;
end
%{
% this check "should" never be necessary.
% Maybe it was originally here for slow-disk protection? 
% Leaving it in for reference for now.
if exist('setup_var.temp_file','var')
    num_checks = 30;
    for tt = 1:num_checks
        if exist(setup_var.temp_file,'file')
            temp_file_error = 0;
            break;
        else
            pause(1)
        end
    end
end
%}
error_flag=0;
if temp_file_error
    error_flag=1;
    if ~exist('setup_var.temp_file','var')
        log_msg =sprintf('Volume %s: Cannot find name of temporary file in variables file: %s; DYING.\n',setup_var.volume_runno,setup_variables);
    else
        log_msg =sprintf('Volume %s: Cannot find temporary file: %s; DYING.\n',setup_var.volume_runno,setup_var.temp_file);
    end
else
    [~,number_of_at_least_partially_reconned_slices,tmp_header] = read_header_of_CStmp_file(setup_var.temp_file);
    unreconned_slices = length(find(~tmp_header));
    if (continue_recon_enabled && ~variable_iterations)
        unreconned_slices = length(find(tmp_header<options.Itnlim));
    end
    if  (unreconned_slices > 0)
        error_flag=1;
        log_msg =sprintf('Volume %s: %i slices appear to be inadequately reconstructed; DYING.\n',setup_var.volume_runno,unreconned_slices);
    else
        log_msg =sprintf('Volume %s: All %i slices appear to be reconstructed; cleaning up volume now.\n',setup_var.volume_runno,number_of_at_least_partially_reconned_slices);
    end
end
yet_another_logger(log_msg,log_mode,log_file,error_flag);
if error_flag==1
    if isdeployed
        quit force;
    else
        error(log_msg);
    end
end

%% Read in temporary data
log_msg =sprintf('Volume %s: Reading data from temporary file: %s...\n',setup_var.volume_runno,setup_var.temp_file);
yet_another_logger(log_msg,log_mode,log_file);
tic
fid=fopen(setup_var.temp_file,'r');
%fseek(fid,header_size*64,-1);
header_size = fread(fid,1,'uint16');
fseek(fid,2*header_size,0);
%data_in=fread(fid,inf,'*uint8');

% our magic number threshold to remove bright noise.
% This is the percentage of data we scale to, instead of a simple scale to
% max, we scale such that the max value preserves 99.95% of our data,
% said otherwise, we overrange 0.05%.
BRIGHT_NOISE_THRESHOLD=0.9995; 

%% min memory mode, we only load 1 full CS slice at a time,
% each is reduced to the proscribed acq dim
% and inserted into a full size acq vol before moving on to the next.
% Potentially we could do better using a  sparse load but thats a lot of
% work.
log_msg =sprintf('%s operating in minimal memory mode\n',mfilename);
yet_another_logger(log_msg,log_mode,log_file);
%lil-dummy is templating a complex value so zero's will work as expected.
lil_dummy = zeros([1,1],'double'); lil_dummy = complex(lil_dummy,lil_dummy);
data_out=zeros(original_dims,'like',lil_dummy);

bytes_per_slice=2*8*recon_dims(2)*recon_dims(3);
% Slice quantiles are not exactly the right answer, so that whole idea
% has been scrapped in favor of the old (silly?) sorted array pct, and
% its done at the end when we take the magnitude.
% slice_quantile=zeros(1,recon_dims(1));

% This histogram collection code is based on the premise that our final
% signal values are related to our input signals by some knowable factor.
% James is NOT convinced that is true!
% Preparing for the switch to when scaling calc is always done at the end.
if exist('scaling','var')   
    %sqrt(recon_dims(2)*recon_dims(3))*(2^16-1)/volume_scale;
    scaling2 = scale_target/(wkspc_mat.volume_scale*wkspc_mat.volume_scale);
else
    scaling2=wkspc_mat.volume_scale/sqrt(recon_dims(2)*recon_dims(3));
end
hist_bins=0:(scaling2/255):scaling2;
volume_hist=histcounts(0,hist_bins); % Initialize an (almost) empty histogram
volume_hist(1)=0;

% do the full set of slices
% rep interval minimum of 2 else it'll just stay quiet.)
rep_interval_sec=2;
slice_processing_start=tic;
% a structure of report times to prevent spamming 
t_rep=struct;
for ss=1:recon_dims(1)
    % if ~mod(ss,10)
    slice_processing_elapsed=toc(slice_processing_start);
    st=sprintf('x_%i',floor(slice_processing_elapsed));
    if mod(floor(slice_processing_elapsed),rep_interval_sec)&& ~isfield(t_rep,st)
        log_msg = sprintf('Slice Processing % 6.2f%%...\n',100* ss/recon_dims(1));
        yet_another_logger(log_msg,log_mode,log_file);
        t_rep.(st)=slice_processing_elapsed;
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
    
    if ~isfield(options,'slicewise_norm') || ~options.slicewise_norm % This is done in slicewise_recon when running slicewise_norm
        t_data_out = t_data_out*wkspc_mat.volume_scale/sqrt(recon_dims(2)*recon_dims(3));
    end
    %% Crop out extra k-space if non-square or non-power of 2,
    % might as well apply fermi filter in k-space, if requested (no QSM requested either)
    % we could mess with output_size and size_type here except that it wouldnt account for dim 1.
    % so instead we defer to until the 3d complex image when we would fermi-filter.
    if sum(original_dims == recon_dims) ~= 3
        t_data_out = fftshift(fftn(fftshift(t_data_out)));
        final_slice_out = t_data_out((recon_dims(2)-original_dims(2))/2+1:end-(recon_dims(2)-original_dims(2))/2, ...
            (recon_dims(3)-original_dims(3))/2+1:end-(recon_dims(3)-original_dims(3))/2);
        final_slice_out = fftshift(ifftn(fftshift(final_slice_out)));
    else
        final_slice_out=t_data_out;
    end
    if exist('scaling','var')
        final_slice_out=scaling*final_slice_out;
    end
    % slice quantiles added to set final image scaling before
    % write_civm_image. This is not a great bit of code because it
    % needs to operate on magnitude data, and has to do an abs in line
    % here.
    % On review of quantile operations, this is not okay, nor is it
    % okay enough to use.
    % slice_quantile(s)=quantile(abs(final_slice_out),BRIGHT_NOISE_THRESHOLD);
    data_out(ss,:,:)= final_slice_out;
    volume_hist=volume_hist+histcounts(abs(final_slice_out(:)),hist_bins); % Cumulative build a volume histogram
    
    %{
        if ~isdeployed && strcmp(getenv('USER'),'rja20') && ~mod(ss,10)
            figure(60)
            %imagesc(abs(squeeze(data_out(round(original_dims(1)/2),:,:))))
            plot(hist_bins(2:end),volume_hist)
            pause(1)
        end
    %}
end
log_msg = sprintf('Slice Processing % 6.2f%%...\n',100* ss/recon_dims(1));
yet_another_logger(log_msg,log_mode,log_file);
% clean up slice_process temp vars to make workspace easier to navigate in
% debugging.
clear ss final_slice_out t_data_out XFM;
% these are display related vars from slice process.
clear t_rep rep_interval_sec slice_processing_start slice_processing_elapsed st;

%% histo scale handling
cs_hist=cumsum(volume_hist);
thresh=BRIGHT_NOISE_THRESHOLD*max(cs_hist);
[a,~]=find(cs_hist'>thresh,1);
if (a == length(hist_bins))
    a=a-1;
end
not_really_data_quantile=(hist_bins(a)+hist_bins(a+1))/2;
suggested_final_scale_file=fullfile(fileparts(recon_mat.scale_file),...
    sprintf('.%s_civm_raw_scale_CALCULATED_SLICEWISE.float',recon_mat.runno));
suggested_final_scale=scale_target/not_really_data_quantile;
clear hist_bins thresh volume_hist cs_hist a not_really_data_quantile;
if (setup_var.volume_number == 1)
    fid_sc = fopen(suggested_final_scale_file,'w');
    % scale write count
    sc_wc = fwrite(fid_sc,suggested_final_scale,'float');
    fclose(fid_sc);
end
clear suggested_final_scale sc_wc fid_sc;
%%
read_time = toc;
log_msg =sprintf('Volume %s: Done reading in temporary data and slice-wise post-processing; Total elapsed time: %0.2f seconds.\n',setup_var.volume_runno,read_time);
yet_another_logger(log_msg,log_mode,log_file);
fclose(fid);

%% Save complex data for QSM BEFORE the possibility of a fermi filter being
% applied.
if write_qsm
    qsm_folder = [workdir '/qsm/'];
    if ~exist(qsm_folder,'dir')
        system(['mkdir ' qsm_folder]);
    end
    qsm_file = [qsm_folder setup_var.volume_runno '_raw_qsm.mat'];
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
            log_msg =sprintf('Volume %s: Done writing raw complex data for QSM: %s; Total elapsed time: %0.2f seconds.\n',setup_var.volume_runno,qsm_file, qsm_write_time);
            yet_another_logger(log_msg,log_mode,log_file);
            %save(qsm_file,'data_out','-v7.3');
        end
    end
end

%% Apply Fermi Filter, and/ or reduce sample
if options.fermi_filter|| exist('output_size','var')
    log_msg =sprintf('Volume %s: Fermi filter is being applied to k-space!\n',setup_var.volume_number);
    yet_another_logger(log_msg,log_mode,log_file);
    % go back to kspace from imgspace.
    data_out = fftshift(fftn(fftshift(data_out)));
    if exist('output_size','var')
        if prod(output_size)>numel(data_out)
            db_inplace(mfilename,'Upsample not understood at the time of writing this and is unimplimented');
        end
        % there is probably a cleaner way to do this indexing operation.
        idx_s=round(0.5*size(data_out)-0.5*output_size)+1;
        idx_e=round(0.5*size(data_out)+0.5*output_size);
        data_out=data_out(idx_s(1):idx_e(1),idx_s(2):idx_e(2),idx_s(3):idx_e(3));
    end
    if options.fermi_filter
        if exist('w1','var')
            data_out = fermi_filter_isodim2_memfix(data_out,w1,w2);
        else
            data_out= fermi_filter_isodim2_memfix(data_out);
        end
    end
    data_out =fftshift(ifftn(fftshift(data_out)));
end
%{
% show the code dev a central slice.
if ~isdeployed && strcmp(getenv('USER'),'THECODEDEV')
    figure(666)
    %imagesc(abs(squeeze(data_out(round(original_dims(1)/2),:,:))))
    imagesc(abs(squeeze(data_out(:,:,round(original_dims(3)/2)))))
    colormap gray
end
%}
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
            
            log_msg =sprintf('Volume %s: Done writing raw complex data for QSM: %s; Total elapsed time: %0.2f seconds.\n',setup_var.volume_runno,qsm_file, qsm_write_time);
            yet_another_logger(log_msg,log_mode,log_file);
            %save(qsm_file,'data_out','-v7.3');
        end
    end
end
% Rename var in memory to avoid accidentally doing invalid operations on
% dat_out
%data_out = abs(data_out);
mag_data = abs(data_out);
clear data_out;
%{
% Move to processing after the procpar file has been processed.
write_archive_tag_nodev(setup_var.volume_runno,['/' target_machine 'space'],original_dims(3),struct1.U_code, ...
    ['.' struct1.U_stored_file_format],struct1.U_civmid,true,images_dir)

%}
%write_civm_image(fullfile(images_dir,[setup_var.volume_runno struct1.scanner_tesla_image_code 'imx']), ...
%    mag_data,struct1.U_stored_file_format,0,1)

%% Pre 17 May 2018 code:
%{
    write_civm_image(fullfile(images_dir,[setup_var.volume_runno databuffer.headfile.scanner_tesla_image_code 'imx']), ...
        mag_data,'raw',0,1)
%}
%% Post 17 May 2018 code:
% while we take stats of our iterations, these are not currently variable
% and may not be the information we're after.
% line search iterations of the minimization are variable, and we dont report those out of the fnl code.
%{
% this was a nice idea, but its causing trouble. Disabled for now.
databuffer=large_array;
databuffer.addprop('headfile');
databuffer.addprop('data');
databuffer.headfile=struct;
%}
t_var=recon_mat.databuffer;
databuffer.headfile=t_var.headfile; clear t_var;
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_total=tmp_header;
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_mean = mean(tmp_header(:));
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_min = min(tmp_header(:));
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_max = max(tmp_header(:));
databuffer.headfile.iterations_per_CSslice_for_L_one_minimization_std = std(tmp_header(:));
% Have to add the volume_runno here because we are initially populated with
% the base runno.
databuffer.headfile.U_runno = setup_var.volume_runno;

try
    first_corner_voxel=recon_mat.first_corner_voxel;
    if options.roll_data
        suffix='';
    else
        suffix='_recommendation';
    end
    databuffer.headfile.(['roll_corner_X' suffix ]) = first_corner_voxel(1);
    databuffer.headfile.(['roll_corner_Y' suffix ]) = first_corner_voxel(2);
    databuffer.headfile.(['roll_first_Z' suffix ])  = first_corner_voxel(3);
    clear suffix;
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
final_scale_file=fullfile(fileparts(recon_mat.scale_file),sprintf('.%s_%i_civm_raw_scale.float',recon_mat.runno,options.selected_scale_volume));
databuffer.headfile.group_max_intensity=max(mag_data(:));
if setup_var.volume_number==options.selected_scale_volume+1 && ~exist(final_scale_file,'file')
    % BJ says: per /cm/shared/workstation_code_dev/recon/CS_v2/testing_and_prototyping/slicewise_hist_test.m
    % It looks like slicewise implementation is 3x faster than this code
    % (e.g. 75s vs 240s for array of 2048x1024x1024)
    % And for data_quantile (a true misnomer here) I observed a difference
    % between the two methods to range from 0.117 +/- 0.064%
    % Given that this is slightly arbitrary, this is MORE than acceptable.
    % Note that the test relied on a simulated bimodal distribution, not
    % real MRI data.
    
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
        ,setup_var.volume_number,final_scale_file,final_scale);
    databuffer.headfile.group_max_atpct=databuffer.headfile.group_max_intensity;
end
mag_data=mag_data*final_scale;
yet_another_logger(log_msg,log_mode,log_file);
databuffer.headfile.divisor=1/final_scale;% legacy just for confusion :D 
fprintf('\tMax value chosen for output scale: %0.14f\n',databuffer.headfile.group_max_atpct);

%% Stuff all meta to headfile here
% rad_mat_option_
databuffer.headfile=combine_struct(databuffer.headfile,options,'CSv2_option_');

%% save civm_raw
databuffer.data = mag_data;clear mag_data; % mag_data clear probably unnecessary, this is just in case.
if ~isfield(options,'unrecognized_fields')
    options.unrecognized_fields=struct;
end
unrecog_cell={'planned_ok'};
unrecog_cell=[unrecog_cell mat_pipe_opt2cell(options.unrecognized_fields)];
write_civm_image(databuffer,[{['write_civm_raw=' setup_var.images_dir],'overwrite','skip_write_archive_tag'} unrecog_cell]);
if options.live_run
    warning('Live run always keeps the work :p');
    options.keep_work=1;
end
if ~options.keep_work && ~options.process_headfiles_only
    % Lets adjust to keeping work until our final headfile is complete.
    % That is, its more than 20KiB big. 
    % 20 was chosen because typical procpars are 60KiB, and incomplete
    % headfiles are typicallyu 5-6KiB.
    %
    % The problem with this setup is that the cleanup will never be run!
    % When streaming procpar's are completed independent of this function,
    % and much later, so we're blind to them. 
    cleanup_ready=0;
    if exist(setup_var.headfile,'file')
        BytesPerKiB=2^10;
        hf_minKiB=20;
        hfinfo=dir(setup_var.headfile);
        if hfinfo.bytes>hf_minKiB*BytesPerKiB
            cleanup_ready=1;
        end
    end
    if cleanup_ready
        if exist(work_subfolder,'dir')
            log_msg =sprintf('Images have been successfully reconstructed; removing %s now...',work_subfolder);
            yet_another_logger(log_msg,log_mode,log_file);
            rm_cmd=sprintf('rm -rf %s',setup_var.work_subfolder);
            system(rm_cmd);
        else
            log_msg =sprintf('Work folder %s already appears to have been removed. No action will be taken.\n',work_subfolder);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    else
        log_msg =sprintf('Images have not been successfully transferred yet; work folder will not be removed at this time.\n');
        yet_another_logger(log_msg,log_mode,log_file);
    end
end

end
