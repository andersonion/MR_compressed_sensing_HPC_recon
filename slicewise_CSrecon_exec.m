function slicewise_CSrecon_exec(matlab_workspace,slice_indices,options_file)
if ~isdeployed    
    matlab_workspace ='/nas4/cof/S67960.work/S67960_m023/work/S67960_m023_workspace.mat';
    
    slice_indices ='021_to_040';
    %global_volume = 1;

   addpath('/cm/shared/workstation_code_dev/recon/CS_v2/sparseMRI_v0.2/'); 

end

%% This eliminates the nested structure of the incoming slice data, and also writes the each
%% slice as they finish instead of waiting until all are done.

slice_numbers=[];
slice_number_strings = strsplit(slice_indices,'_');
for ss = 1:length(slice_number_strings)
    temp_string=slice_number_strings{ss};
    if strcmp(temp_string,'to')
        begin_slice = str2double(slice_number_strings{ss-1})+1;
        end_slice = str2double(slice_number_strings{ss+1})-1;
        temp_vec = begin_slice:1:end_slice;
    else
        temp_vec = str2double(temp_string);
    end
    slice_numbers = [slice_numbers temp_vec];
end
slice_numbers=unique(slice_numbers);


%if ~isdeployed
%    addpath(genpath('/home/rmd22/Documents/MATLAB/'));
%end

%% Make sure the goddam workspace file exist
log_mode = 3;
log_file ='';
if  (~exist(matlab_workspace,'file'))
    error_flag = 1;
    log_msg =sprintf('Matlab workspace (''%s'') does not exist. Dying now.\n',matlab_workspace);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    quit force
else
    a = who('-file',matlab_workspace,'aux_param');
    if ~size(a)
        error_flag = 1;
        log_msg =sprintf('Matlab workspace (''%s'') exists, but parameter ''aux_param'' not found. Dying now.\n',matlab_workspace);
        yet_another_logger(log_msg,log_mode,log_file,error_flag);
        quit force
    end
end


if exist('options_file','var')
    if exist(options_file,'file')
        load(options_file);
    end
end

%% Load common workspace params
tic
load(matlab_workspace,'aux_param');
load(matlab_workspace,'param');
time_to_load_common_workspace=toc;
log_mode = 1;
log_file = aux_param.volume_log_file;

log_msg =sprintf('Time to load common workspace: %0.2f seconds.\n',time_to_load_common_workspace);
yet_another_logger(log_msg,log_mode,log_file)

%param.Itnlim=98; %Testing p

%% Setup common variables
%mask_size=aux_param.maskSize;
mask=aux_param.mask;
%DN=aux_param.DN;
TVWeight=aux_param.TVWeight;
xfmWeight=aux_param.xfmWeight;
volume_scale=aux_param.volume_scale;
temp_file=aux_param.tempFile;
recon_dims=aux_param.recon_dims;
CSpdf=aux_param.CSpdf; % We can find the LESS THAN ONE elements to recreate original slice array size
phmask=aux_param.phmask;

OuterIt=length(TVWeight);%aux_param.OuterIt;

wavelet_dims=aux_param.waveletDims;

if isfield(aux_param,'waveletType')
    wavelet_type=aux_param.waveletType;
else
    wavelet_type = 'Daubechies';
end

XFM = Wavelet(wavelet_type,wavelet_dims(1),wavelet_dims(2));

param.XFM = XFM;
param.TV=TVOP;

recon_options=struct;

if ~isdeployed
    recon_options.verbosity = 1;
    recon_options.log_file = log_file;
    recon_options.variable_iterations = 1;
else
    if exist('variable_iterations','var')
        recon_options.variable_iterations = variable_iterations;
    end
    
    if exist('volume_log_file','var')
        recon_options.log_file=volume_log_file;
    end
    
    if exist('log_mode','var')
        recon_options.log_mode = log_mode;
    end
    
    if exist('verbosity','var')
        recon_options.verbosity=verbosity;
    end
    
    if exist('make_nii_animation','var')
        recon_options.make_nii_animation = make_nii_animation;
    end
    
    if exist('convergence_limit','var')
        recon_options.convergence_limit=convergence_limit;
    end
    if exist('convergence_window','var')
        recon_options.convergence_window=convergence_window;
    end
end

current_Itnlim = param.Itnlim;
mm = matfile(matlab_workspace,'Writable',false);

%im_result=zeros(dims(2),dims(3),length(slice_numbers));
%header_size = dims(1);
%header_size = dims(1)*64;% 8 May 2017, BJA: Change header from binary to local scaling factor
%header_size = dims(1)*16;% 15 May 2017, BJA: Change header from local scaling factor to number_of_completed_iterations
header_size = 1+recon_dims(1);% 26 September 2017, BJA: 1st uint16 bytes are header length, + number of x slices of uint16 bits
%% Reconstruct slice(s)
for index=1:length(slice_numbers)
    slice_index=slice_numbers(index);
    fid=fopen(temp_file,'r+');
    %work_done = fread(fid,dims(1),'*uint8');
    header_length = fread(fid,1,'uint16'); % Should be the same size as header_size
    work_done = fread(fid,header_length,'uint16'); % 15 May 2017, BJA; changed header from double to uint16; will indicate number of iterationsperformed
    %work_done = fread(fid,dims(1),'double'); % 8 May 2017, BJA: converting header from binary to double local_scaling
    fclose(fid);
    %previous_Itnlim = 0;
    continue_work = 0;
    c_work_done = work_done(slice_index);
    previous_Itnlim = c_work_done;
    if (c_work_done > 0);
        %previous_Itnlim = floor(c_work_done/1000000); % 9 May 2017, BJA: Adding ability to continue CS recon with more iterations.
       
        if (current_Itnlim > previous_Itnlim)
            param.Itnlim = current_Itnlim - previous_Itnlim;
            continue_work=1;
            log_msg =sprintf('Slice %i: Previous recon work done (%i iterations); continuing recon up to maximum total of %i iterations.\n',slice_index,previous_Itnlim,current_Itnlim);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    end
    
    if ((c_work_done == 0) || (continue_work)) %~work_done(slice_index)
        
        %% Load slice specific data
        tic
        
        %slice_data = complex(double(mm.real_data(slice_index,:)),double(mm.imag_data(slice_index,:)) );% 8 May 2017, BJ: creating sparse, zero-padded slice here instead of during setup
        slice_data = complex(mm.real_data(slice_index,:),mm.imag_data(slice_index,:));
        param.data = zeros(size(mask),'like',slice_data); % Ibid
        %param.data = zeros([size(mask)],'like',slice_data);
        param.data(mask(:))=slice_data(:); % Ibid
        time_to_load_sparse_data = toc;
        
        log_msg =sprintf('Slice %i: Time to load sparse data:  %0.2f seconds.\n',slice_index,time_to_load_sparse_data);
        yet_another_logger(log_msg,log_mode,log_file);
        
        tic
        
        im_zfwdc = ifft2c(param.data./CSpdf)/volume_scale; % this compensates the intensity for the undersampling
        
        ph = exp(1i*angle((ifft2c(param.data.*phmask))));
        
        param.FT = p2DFT(mask, recon_dims(2:3), ph, 2);
        
        %Dev mode
        %{
        if exist('res','var')
            clear res
            'Clearing res'
         end
        %}
        
        if (c_work_done == 0)
            res=XFM*im_zfwdc;
            
        else
            recon_options.convergence_window = 3;
            %data_offset= header_size + (8*dims(2)*dims(3)*(slice_index-1));
            s_vector_length = recon_dims(2)*recon_dims(3);
            data_offset= 2*header_size + (2*8*s_vector_length*(slice_index-1)); % Each slice is double dim_y*dim_z real, then double dim_y*dim_z imaginary
            fid=fopen(temp_file,'r+');
            fseek(fid,data_offset,-1);
            reconned_slice=fread(fid,2*s_vector_length,'double');
            fclose(fid);
            
            res=complex(reconned_slice(1:s_vector_length),reconned_slice((s_vector_length+1):end));
            res=reshape(res,[recon_dims(2) recon_dims(3)]);
            
            %{
            temp_res=sqrt(mask_size)/myscale*temp_res;
            
            if (sum(dims1-dims)>0)
                temp_res = fftshift(ifftn(fftshift(temp_res)));
                res= padarray(temp_res,[dims1(2)-dims(2) dims1(3)-dims(3)]/2,0,'both');
                res=fftshift(fftn(fftshift(res)));
                
            else
            %}
            
            %res=XFM*res;
            %res =XFM*im_zfwdc ; %pick up where we left off...
            
        end
        
        
        time_to_set_up = toc;
        
        log_msg =sprintf('Slice %i: Time to set up recon:  %0.2f seconds.\n',slice_index,time_to_set_up);
        yet_another_logger(log_msg,log_mode,log_file);
        
        %%
        %tic
        
        for n=1:OuterIt
            param.TVWeight =TVWeight(n);     % TV penalty
            param.xfmWeight = xfmWeight(n);  % L1 wavelet penalty
            [res, iterations_performed, time_to_recon] = fnlCg_verbose(res, param,recon_options);
        end
        %time_to_recon = toc;
        
        log_msg =sprintf('Slice %i: Time to reconstruct data:  %0.2f seconds.\n',slice_index,time_to_recon);
        yet_another_logger(log_msg,log_mode,log_file);
        
        if ~isdeployed
            plotting_today_BJ = 1;
        else
            plotting_today_BJ = 0;
        end
        
        if plotting_today_BJ
            scale_file=aux_param.scaleFile;
            fid_sc = fopen(scale_file,'r');
            scaling = fread(fid_sc,inf,'*float');
            fclose(fid_sc);
            im_res = XFM'*res;
            im_res = im_res*volume_scale/sqrt(recon_dims(2)*recon_dims(3)); % --->> check this, sqrt of 2D plane elements required for proper scaling
            
            
            %% Crop out extra k-space if non-square or non-power of 2
            %if sum(original_dims == recon_dims) ~= 3
            %    im_res = fftshift(fftn(fftshift(im_res)));
            %    im_res = im_res((recon_dims(2)-original_dims(2))/2+1:end-(recon_dims(2)-original_dims(2))/2, ...
            %       (recon_dims(3)-original_dims(3))/2+1:end-(recon_dims(3)-original_dims(3))/2);
            %    im_res = fftshift(ifftn(fftshift(im_res)));
            
            %figure(1000+slice_index)
            figure(slice_index)
            im_to_plot = double(abs(im_res')*scaling);
            imagesc(im_to_plot)
            colormap gray
            axis xy
            pause(3)
            
        end
        
        
        %{
        tic
        im_res = XFM'*res;
        
        
        im_res = im_res*volume_scale/sqrt(mask_size); % --->> check this, sqrt of 2D plane elements required for proper scaling
        
        
        %% Crop out extra k-space if non-square or non-power of 2
        if sum(dims == dims1) ~= 3
            im_res = fftshift(fftn(fftshift(im_res)));
            im_res = im_res((dims1(2)-dims(2))/2+1:end-(dims1(2)-dims(2))/2, ...
                (dims1(3)-dims(3))/2+1:end-(dims1(3)-dims(3))/2);
            im_res = fftshift(ifftn(fftshift(im_res)));
        end
        %im_to_write =double(abs(im_res)*scaling);
        %}
        
        %im_to_write =double(abs(im_res)); % 8 May 2017, BJA: moving global scaling to cleanup
        
        %%
        
        %{
        im_to_write = zeros([2, numel(im_res)],'single');
        im_to_write(1,:)=single(real(im_res(:)));
        im_to_write(2,:)=single(imag(im_res(:)));
        
        im_to_write = reshape(im_to_write,[2*numel(im_res), 1]);
        
        image_to_write = typecast(im_to_write(:),'uint8');
        %}
        
        tic
        image_to_write = [real(res(:))' imag(res(:))'];
        
        
        fid=fopen(temp_file,'r+');
        header_length = fread(fid,1,'uint16'); % Should be the same size as header_size
        work_done = fread(fid,header_length,'uint16');
        
        if (~work_done(slice_index) || ((continue_work) && (work_done(slice_index) < current_Itnlim)))
            %Write data
            s_vector_length = recon_dims(2)*recon_dims(3);
            data_offset=(2*8*s_vector_length*(slice_index-1));
            fseek(fid,data_offset,0);
            fwrite(fid,image_to_write,'double'); %'n'
            log_msg =sprintf('Slice %i: Successfully reconstructed and written to %s.\n',slice_index,temp_file);
            yet_another_logger(log_msg,log_mode,log_file);
            
            
            %Write header
            %fseek(fid,(slice_index-1),-1);
            header_info = uint16(previous_Itnlim+iterations_performed);
            %fseek(fid,8*(slice_index-1),-1); % 8 May 2017, BJA: changing header from binary to double local_scaling factor.
            %fseek(fid,2*(slice_index-1),-1); % 15 May 2017, BJA: header stores number of iterations now
            fseek(fid,2*(slice_index),-1); %Need to account for the first two bytes which store header length.
            %fwrite(fid,header_info,'double');
            fwrite(fid,header_info,'uint16'); % 15 May 2017, BJA: see directly above
            % fclose(fid);
            
            log_msg =sprintf('Slice %i: Reconstruction flag written to header of %s.\n',slice_index,temp_file);
            yet_another_logger(log_msg,log_mode,log_file);
            
            time_to_write_data=toc;
            log_msg =sprintf('Slice %i: Time to write data:  %0.2f seconds.\n',slice_index,time_to_write_data);
            yet_another_logger(log_msg,log_mode,log_file);
        end
        fclose(fid);
    else
        log_msg =sprintf('Slice %i: Previously reconstructed; skipping.\n',slice_index);
        yet_another_logger(log_msg,log_mode,log_file);
    end
end
return
end