function setup_volume_work_for_CSrecon_exec(setup_vars,volume_number)
%CS_RECON_CLUSTER_SETUP_WORK_EXEC An executable MATLAB script for setting
%up each volume of CS reconstruction in order to avoid saturating the
%master node (in the context of DTI, with many many volumes to recon.

%% Update of original version (implied _v1)
if ~isdeployed
    % {
    %setup_vars = '/civmnas4/rja20/Z56017.work/Z56017_m0/work/Z56017_m0_setup_variables.mat';
    %volume_number = '1';
    addpath('/cm/shared/workstation_code_dev/recon/CS_v2/CS_utilities');
    addpath('/cm/shared/workstation_code_dev/recon/CS_v2/sparseMRI_v0.2');
    %}
   setup_vars='/civmnas4/rja20/N96041.work/N96041_m6/N96041_m6_setup_variables.mat';
   volume_number='7'
end
make_tmp = 0;
%%   Import Variables
load(setup_vars);

if ~isdeployed % {
    options.roll_data = 1;
end

log_file=volume_log_file;
log_mode=1;
%recon_file = variables.recon_file;
%procpar_path = variables.procparpath;
%outpath = variables.outpath;
%scale_file = variables.scale_file;
%target_machine = variables.target_machine;
if ~exist('TVWeight','var')
    TVWeight = 0.0012;
end
if ~exist('xfmWeight','var')
    xfmWeight = 0.006;
end
if ~exist('Itnlim','var')
    Itnlim = 98;
end
if ~exist('wavelet_dims','var')
    wavelet_dims = [12 12]; % check this default
end
if ~exist('wavelet_type','var')
    wavelet_type = 'Daubechies';
end
%% Load data
load(recon_file);
% mask should already be processed -- one  of the very first things done!
%if ~exist('procpar_path','file')
%    procpar_path = ;
%end
%mask = skipint2skiptable(procpar_path); %sampling mask
volume_number=str2double(volume_number);
%% Immediately check to see if we still need to set up the work (a la volume manager)
[starting_point, log_msg] = check_status_of_CSrecon(workdir,volume_runno);
make_workspace = 0;
make_tmp = 0;
work_subfolder = fullfile(workdir,'work');
volume_workspace_file = fullfile(work_subfolder,[volume_runno '_workspace.mat']);
temp_file = [work_subfolder '/' volume_runno '.tmp'];
if (starting_point == 2)
    make_workspace = 1;
    try
        dummy_mf = matfile(volume_workspace_file,'Writable',false);
        tmp_param = dummy_mf.param;
        make_workspace = 0;
    catch
    end
    if ~exist(temp_file,'file')
        make_tmp = 1;
    end
elseif (starting_point < 2)
    error_flag = 1
    log_msg =sprintf('Volume %s: Source fid not ready yet! Unable to run recon setup.\n',volume_runno);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
else
    log_msg =sprintf('Volume %s: Setup work appears to have been previously completed; skipping.\n',volume_runno);
    yet_another_logger(log_msg,log_mode,log_file);
    make_workspace = 0;
end

if (make_workspace)
    tic
    %data=single(zeros([floor(npoints/2),n_sampled_points]));
    double_down = 1; % Need to test this feature, if we want to keep double processing for all fft operations, and beyond.
    fid_volume_number =1;
    only_non_zeros = 1;
    max_blocks = 1;
    data = load_fidCS(volume_fid,max_blocks,ntraces/nechoes,npoints,bitdepth,fid_volume_number,original_dims,only_non_zeros,double_down);
    %data = double(data); %This should be replaced by setting double_down to 1.
    fid_load_time = toc;
    log_msg =sprintf('Volume %s: fid loaded successfully in %0.2f seconds.\n',volume_runno,fid_load_time);
    yet_another_logger(log_msg,log_mode,log_file);
    tic
    data = fftshift(ifft(fftshift(data,1),[],1),1); % take ifft in the fully sampled dimension
    fft_time=toc;
    log_msg =sprintf('Volume %s: Fourier transform along fully sampled dimension completed in %0.2f seconds.\n',volume_runno,fft_time);
    yet_another_logger(log_msg,log_mode,log_file);

    m = matfile(recon_file,'Writable',true);

    %% Calculate group scaling from first b0 image
    %if ((~exist(scale_file,'file') || (options.roll_data && ~isfield(m,'shift_modifier'))) && (volume_number==1))
    if ((~exist(scale_file,'file') || (~isfield(m,'shift_modifier'))) && (volume_number==1))
        [scaling, scaling_time,shift_modifier,first_corner_voxel] = calculate_CS_scaling(original_mask,data,original_pdf,original_dims(1),options.roll_data);
        m.first_corner_voxel=first_corner_voxel;
        %{
            tic
            current_slice=zeros([size(mask0)],'like',current_data);
            for n = 1:dims(1)
                current_slice(mask0(:))=current_data(n,:);
                temp_data = abs(ifftn(current_slice./mypdf0)); % 8 May 2017, BJA: Don't need to waste computations on fftshift for scaling calculation
                qq(n)= max(temp_data(:));%quantile(temp_data(:),thresh);
            end
            toc
            q = quantile(qq,thresh);
            scaling = (2^16-1)/q; % we plan on writing out uint16 not int16, though it won't show up well in the database
            scaling = double(scaling);
        %}
        log_msg =sprintf('Volume %s: volume scaling (%f) calculated in %0.2f seconds\n',volume_runno,scaling,scaling_time);
        yet_another_logger(log_msg,log_mode,log_file);
        %m = matfile(recon_file,'Writable',true); %moved outside of code
        %block
        m.scaling = scaling;
        
        m.shift_modifier=shift_modifier;
        
        % Write scaling factor to scale file
        fid = fopen(scale_file,'w');
        fwrite(fid,scaling,'float');
        fclose(fid);
    else
        %if (options.roll_data)
           shift_modifier=m.shift_modifier;
           first_corner_voxel=m.first_corner_voxel;
        %end
    end
    %% Prep data for reconstruction
    % Calculate scaling
    if (exist('scaling','var') && (volume_number == 1) && ~(sum((recon_dims - original_dims))))
        volume_scale = sqrt(recon_dims(2)*recon_dims(3))*(2^16-1)/scaling; % We've already done the heavy lifting for this calculation, if array size doesn't change.
    else
        tic
        current_slice=zeros([size(mask)],'like',data);
        qq=zeros([1 recon_dims(1)]);
        for n = 1:recon_dims(1)
            current_slice(mask(:))=data(n,:);
            temp_data = abs(ifftn(current_slice./CSpdf)); % 8 May 2017, BJA: Don't need to waste computations on fftshift for scaling calculation
            qq(n)=max(temp_data(:));%quantile(temp_data(:),thresh);
        end
        thresh = .999999999;
        volume_scale = sqrt(recon_dims(2)*recon_dims(3))*quantile(qq,thresh);
        %fid = fopen(scale_file,'r');
        %scaling = fread(fid,inf,'float');
        %fclose(fid);
        optimized_for_memory_time = toc;
        log_msg =sprintf('Volume %s: volume scaling calculated in %0.2f seconds.\n',volume_runno,optimized_for_memory_time);
        yet_another_logger(log_msg,log_mode,log_file);
    end
    % scale data such that the maximum image pixel in zf-w/dc is around 1
    % this way, we can use similar lambda for different problems
    data = data/volume_scale;
    mf=matfile(setup_vars,'Writable',true);
    mf.volume_scale = volume_scale;
    %% Define auxillary parameters to pass to compiled job
    aux_param.mask=mask;
    %aux_param.maskSize=numel(mask);
    aux_param.originalMask=original_mask;
    %aux_param.DN = DN;
    aux_param.TVWeight=TVWeight;
    aux_param.xfmWeight=xfmWeight;
    aux_param.volume_scale=volume_scale;
    aux_param.scaleFile=scale_file;
    aux_param.tempFile=temp_file;
    aux_param.volume_log_file = volume_log_file;
    %aux_param.totalSlices=recon_dims(1);
    aux_param.original_dims=original_dims;
    aux_param.recon_dims=recon_dims;
    aux_param.waveletDims=wavelet_dims;
    aux_param.waveletType=wavelet_type;
    aux_param.CSpdf=CSpdf;
    %aux_param.originalMypdf=mypdf0;
    aux_param.phmask=phmask;
    if isfield(options,'verbosity')
        aux_param.verbosity=verbosity;
    end
    %%
    param = init;
    param.Itnlim = Itnlim;  % Should this be a function of necho?
    
    %% Save common variable file
    if ~exist(volume_workspace_file,'file')
        tic
        
        if (options.roll_data)
            disp('Attempting to roll data via kspace...')
            Ny=original_dims(2);
            Nz=original_dims(3);
            ky_profile=(shift_modifier(2)/(Ny))*(1:1:Ny);
            kz_profile=(shift_modifier(3)/(Nz))*(1:1:Nz);         
            [Kyy,Kzz]=meshgrid(ky_profile,kz_profile);
            phase_matrix = exp(-2*pi*1i*(Kyy+Kzz));
            phase_vector=phase_matrix(original_mask(:));
        
            data=circshift(data,round(shift_modifier(1)));
            for xx=1:original_dims(1);
                data(xx,:)=phase_vector'.*data(xx,:);
            end  
            
        end
        
        real_data = real(data);
        imag_data = imag(data);
        savefast2(volume_workspace_file,'real_data','imag_data');
        save(volume_workspace_file,'aux_param','-append');
        save(volume_workspace_file,'param','-append');
        time_to_write_master_mat_file=toc;
        log_msg =sprintf('Volume %s: master .mat file written in %0.2f seconds.\n',volume_runno,time_to_write_master_mat_file);
        yet_another_logger(log_msg,log_mode,log_file);
    end
end
if (make_tmp)
    %% Create temporary volume for intermediate work
    header_size = (original_dims(1))*2; % Header data should be uint16, with the very first value telling how long the rest of the header is.
    header_length = uint16(original_dims(1));
    header_byte_size = (2 + header_size);
    data_byte_size =  8*2*recon_dims(2)*recon_dims(3)*recon_dims(1); % 8 [bytes for double], factor of 2 for complex
    file_size = header_byte_size+data_byte_size;
    work_done=zeros([header_length 1]);
    if ~exist('temp_file','var')
        temp_file = [work_subfolder '/' volume_runno '.tmp'];
    end
    if ~exist(temp_file,'file')
        tic
        master_host='civmcluster1';
        host=getenv('HOSTNAME');
        host_str = '';
        if ~strcmp(master_host,host)
            host_str = ['ssh ' master_host];
        end
        fallocate_cmd = sprintf('%s fallocate -l %i %s',host_str,file_size,temp_file);
        [status,~]=system(fallocate_cmd);
        pause(2); % We seem to be having problems with dir not seeing the temp_file.
        fmeta=dir(temp_file);
        if isempty(fmeta)
            m_file_size = 0;
        else
            m_file_size = fmeta.bytes;
        end
        if status || (m_file_size ~= file_size)
            fprintf(1,'AAAAAAHHHHH!!! fallocate command failed!  Using dd command instead to initialize .tmp file');
            preallocate=sprintf('dd if=/dev/zero of=%s count=1 bs=1 seek=%i',temp_file,file_size-1);
            system(preallocate)
        end
        fid=fopen(temp_file,'r+');
        fwrite(fid,header_length,'uint16');
        fwrite(fid,work_done(:),'uint16');
        fclose(fid);
        
        chmod_temp_cmd = ['chmod 664 ' temp_file];
        system(chmod_temp_cmd);
        time_to_make_tmp_file = toc;
        log_msg =sprintf('Volume %s: .tmp file created in %0.2f seconds.\n',volume_runno,time_to_make_tmp_file);
        yet_another_logger(log_msg,log_mode,log_file);
    end
end


end

function [scaling,scaling_time,shift_modifier,first_corner_voxel] = calculate_CS_scaling(current_mask,current_data,mypdf0,n_slices,roll_data)
shift_modifier=[ 0 0 0 ];
thresh = .999999999; % only clip out very noisy voxels (e.g. zippers, artifacts), and not the eyes
tic
x_dim=n_slices;
[y_dim,z_dim]=size(current_mask);
current_slice=zeros([y_dim z_dim],'like',current_data);
qq=zeros([1,x_dim]);
d1=1; % I'm never sure if how the dims map to the data as I imagine it...
d2=2; % May need to swap these...
%if (roll_data)
    y_sums=zeros([size(current_mask,d1),x_dim]);
    z_sums=zeros([size(current_mask,d2),x_dim]);
    x_sum=qq;
    %y_sum=zeros([1, size(current_mask,d1)]);
    %z_sum=zeros([1, size(current_mask,d2)]);
%end
for n = 1:x_dim
    current_slice(current_mask(:))=current_data(n,:);
    temp_data = abs(ifftn(current_slice./mypdf0)); % 8 May 2017, BJA: Don't need to waste computations on fftshift for scaling calculation
    qq(n)= max(temp_data(:));%quantile(temp_data(:),thresh);
    %if (roll_data)   
        y_sums(:,n)=mean(temp_data,d2);
        z_sums(:,n)=mean(temp_data,d1)';
        x_sum(n)=mean(temp_data(:));
    %end
end

q = quantile(qq,thresh);
%if (roll_data)
    x_sum=x_sum';
    y_sum=circshift(mean(y_sums,2),round(y_dim/2));
    z_sum=circshift(mean(z_sums,2),round(z_dim/2));
    
    [x_min,first_corner_voxel(1)] = min(x_sum);
    [y_min,first_corner_voxel(2)] = min(y_sum);
    [z_min,first_corner_voxel(3)] = min(z_sum);
    
    vs=[x_dim y_dim z_dim];
    vc=zeros(1,3);
    center=vc;
    vc=round(vs/2);
    center=first_corner_voxel+vc-1;
    center(center>vs)=center(center>vs)-vs(center>vs);
    shift_modifier=vc-center;
    
    x_sum=circshift(x_sum,round(shift_modifier(1)));
    y_sum=circshift(y_sum,round(shift_modifier(2)));
    z_sum=circshift(z_sum,round(shift_modifier(3)));
    
    first_3rd_idx = round(vs/3);
    last_3rd_idx = round(2*vs/3)+1;
    cof=1.2;%cof=1.1; % Cof=> "coeffecient"
    lmin(1)=find((x_sum(1:first_3rd_idx(1))<cof*x_min),1,'last');
    lmin(2)=find((y_sum(1:first_3rd_idx(2))<cof*y_min),1,'last');
    lmin(3)=find((z_sum(1:first_3rd_idx(3))<cof*z_min),1,'last');
    
    umin(1)=find((x_sum(last_3rd_idx(1):end)<cof*x_min),1);
    umin(2)=find((y_sum(last_3rd_idx(2):end)<cof*y_min),1);
    umin(3)=find((z_sum(last_3rd_idx(3):end)<cof*z_min),1);
    
    umin=umin+last_3rd_idx-1;
    
    new_c=round((umin-lmin)/2+lmin);
    center=new_c-shift_modifier;% adjust new center back for our original position.
    center(center>vs)=center(center>vs)-vs(center>vs);
    first_corner_voxel=center+1-vc;
    first_corner_voxel(first_corner_voxel<0)=first_corner_voxel(first_corner_voxel<0)+vs(first_corner_voxel<0);

    shift_modifier=vc-center; %X seemed almost right, but Y/Z off by half volume

 
%end
scaling_time = toc;
scaling = (2^16-1)/q; % we plan on writing out uint16 not int16, though it won't show up well in the database
scaling = double(scaling);
end
