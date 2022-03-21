function setup_volume_work_for_CSrecon_exec(setup_variables)
% SETUP_VOLUME_WORK_FOR_CSrecon_exec(setup_variables)
% An executable MATLAB script for setting up each volume of CS 
% reconstruction in order to avoid saturating the master node (in the 
% context of DTI, with many many volumes to recon.
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

if ~isdeployed
    % our mfilename command is failire here while runing live, not gonna bothter to track that down now.
    % run(fullfile(fileparts(mfilename('fullfile')),'compile_commands','compile__pathset.m'))
else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end
%%   Import Variables
setup_var=matfile(setup_variables);
log_file=setup_var.volume_log_file;
log_mode=1;
%% Load data
recon_mat=matfile(setup_var.recon_file);
options=recon_mat.options;
volume_number=setup_var.volume_number;
volume_runno=setup_var.volume_runno;
%% Immediately check to see if we still need to set up the work (a la volume manager)
% [starting_point, log_msg] = check_status_of_CSrecon(setup_var.volume_dir,volume_runno);
[starting_point, ~] = volume_status(setup_var.volume_dir,volume_runno);
make_workspace = 0;
make_tmp = 0;
% recreating vol_mat variable
% work_subfolder = fullfile(vol_mat.workdir,'work');
% setup_var.volume_workspace = fullfile(setup_var.work_subfolder,[volume_runno '_workspace.mat']);
% temp_file = [work_subfolder '/' volume_runno '.tmp'];
% this was re-creating vol_mat.temp_file
if (starting_point == 2)
    missing_vars=matfile_missing_vars(setup_var.volume_workspace,{'imag_data','real_data'});
    %{
    try
        varinfo=whos('-file',setup_var.volume_workspace);
    catch
    end
    if ~exist('varinfo','var') ...
            || ( ~ismember('imag_data',{varinfo.name}) ...
            || ~ismember('real_data',{varinfo.name})  )
        make_workspace = 1;
    end
    %}
    if missing_vars; make_workspace=1; end
    if ~exist(setup_var.temp_file,'file'); make_tmp = 1; end
elseif (starting_point < 2)
    error_flag = 1;
    log_msg =sprintf('Volume %s: Source fid not ready yet! Unable to run recon setup.\n',volume_runno);
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
else
    log_msg =sprintf('Volume %s: Setup work appears to have been previously completed; skipping.\n',volume_runno);
    yet_another_logger(log_msg,log_mode,log_file);
    make_workspace = 0;
end

if (make_workspace || ~islogical(options.CS_preview_data) )
    t_make_workspace=tic;
    % working in double precision was not tested before it was made
    % default.
    % Thank our former code maintainer :p.
    process_precision = 'double';
    % this is always one BECAUSE we always scrape out the points for this
    % volume from the fid before we transfer it, meaning every fid is a one
    % vol fid.
    fid_volume_number =1;
    only_non_zeros = 1;
    max_blocks = 1;
    % Why is there a custom load function here? Shouldnt we just use the
    % load_fid(agilent_data_path) function?
    %{
    data = load_fidCS(setup_var.volume_fid, ...
        max_blocks, ...
        recon_mat.ntraces/recon_mat.nechoes, ...
        recon_mat.npoints, recon_mat.bitdepth, ...
        fid_volume_number, ...
        recon_mat.original_dims,   only_non_zeros, process_precision  );
    %}
    data = load_fidCS(setup_var.volume_fid, ...
        max_blocks, ...
        recon_mat.rays_per_block/recon_mat.nechoes, ...
        recon_mat.dim_x*2, recon_mat.kspace_data_type, ...
        fid_volume_number, ...
        recon_mat.original_dims,   only_non_zeros, process_precision  );
    if ndims(data)==3
        %% convert back to 2d data, most of the time we dont get 3d from loadfid cs
        data=reshape(data,[size(data,1),size(data,2)*size(data,3)]);
    end
    fid_load_time = toc(t_make_workspace);
    log_msg =sprintf('Volume %s: fid loaded successfully in %0.2f seconds.\n',volume_runno,fid_load_time);
    yet_another_logger(log_msg,log_mode,log_file);
    t_fft=tic;
    data = fftshift(ifft(fftshift(data,1),[],1),1); % take ifft in the fully sampled dimension
    fft_time=toc(t_fft);
    log_msg =sprintf('Volume %s: Fourier transform along fully sampled dimension completed in %0.2f seconds.\n',volume_runno,fft_time);
    yet_another_logger(log_msg,log_mode,log_file);
    if options.CS_preview_data
        t_preview=tic;
        warning('Preview data wont do any recon at current.');
        preview_stamp=fullfile(setup_var.volume_dir,'.preview.time');
        system(sprintf('touch %s',preview_stamp));
        preview_imgs=CS_preview_data(recon_mat.original_mask,data,fullfile(setup_var.volume_dir,volume_runno),options.CS_preview_data);
        scp_cmds=cell(1,numel(preview_imgs)+1);
        for pn=1:numel(preview_imgs)
            scp_to_engine=sprintf('scp -p %s %s@%s.dhe.duke.edu:/%sspace/',...
                preview_imgs{pn},sys_user(),options.target_machine,options.target_machine);
            shell_s=sprintf('if [ %s -nt %s ]; then %s & fi',...
                preview_imgs{pn}, preview_stamp, scp_to_engine);
            scp_cmds{pn}=shell_s;
            %{
            [s,sout]=system(shell_s);
            if s~=0 
                warning('problem sending %s: %s',preview_imgs{pn},sout);
            end
            %}
        end
        scp_cmds{end}='wait';
        [s,sout]=system(strjoin(scp_cmds,' ; '));
        if s~=0
            warning('problem sending %s: %s',preview_imgs{pn},sout);
        end
        preview_time=toc(t_preview);
        log_msg=sprintf('Volume %s: Preview and scp time is %0.2f\n',volume_runno,preview_time);
        yet_another_logger(log_msg,log_mode,log_file);
        return;
    end
    recon_mat_vars = who('-file', setup_var.recon_file);
    % ismember('shift_modifier', variableInfo) % returns false if not available
    %% Calculate group scaling from first b0 image
    %if ((~exist(scale_file,'file') || (options.roll_data && ~isfield(m,'shift_modifier'))) && (volume_number==1))
    if (volume_number==1) ...
            && (  ~exist(recon_mat.scale_file,'file') ... %|| ~isfield(m,'shift_modifier')  )
            || ~ismember('shift_modifier',recon_mat_vars)  )        
        [scaling, scaling_time,shift_modifier,first_corner_voxel] = calculate_CS_scaling( ...
            recon_mat.original_mask,  data, recon_mat.original_pdf, ...
            recon_mat.dim_x,  options.roll_data);
        %recon_mat=matfile(setup_var.recon_file,'Writable',true);
        recon_mat.Properties.Writable = true;
        recon_mat.first_corner_voxel=first_corner_voxel;
        % Write scaling factor to scale file
        fid = fopen(recon_mat.scale_file,'w');
        fwrite(fid,scaling,'float');
        fclose(fid);
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
        log_msg =sprintf('Volume %s: Initial global scaling (%f) calculated in %0.2f seconds\n',volume_runno,scaling,scaling_time);
        yet_another_logger(log_msg,log_mode,log_file);
        recon_mat.scaling = scaling;
        recon_mat.shift_modifier=shift_modifier;
        recon_mat.Properties.Writable = false;
        clear first_corner_voxel fid;
    else
        if ismember('scaling',recon_mat_vars)
           scaling=recon_mat.scaling;
        end
        if ismember('shift_modifier',recon_mat_vars)
           shift_modifier=recon_mat.shift_modifier;
        end
        %{
        if ismember('first_corner_voxel',recon_mat_vars)
           first_corner_voxel=recon_mat.first_corner_voxel;
        end
        %}
    end
    %% Prep data for reconstruction
    % Calculate per volume scaling the study scale has already been
    % calculated.
    
    % BJ: let's investigate if it makes more since to do slice_scaling
    % rather than volume_scaling
    
    recon_dims=recon_mat.recon_dims;
    if (exist('scaling','var') && (volume_number == 1) ...
            && ~(sum((recon_mat.recon_dims - recon_mat.original_dims))))
        % If we've calculated scale and its first volume, and we have same
        % recon and original dims, (2^16-1)/scaling is the q as calculated.
        volume_scale = sqrt(recon_dims(2)*recon_dims(3))*(2^16-1)/scaling;
    else
        %% Calculate individual volume scale divisor using quantile... 
        % this code is suspected of being incorrect by james, with evidence
        % of poor scaling in recons from gary. 
        t_scale_calc=tic;
        mask=recon_mat.mask;
        current_slice=zeros(size(mask),'like',data);
        qq=zeros([1 recon_dims(1)]);
        % This loop is slow, but memory efficient. We might be able to
        % smartly do this some other way. 
        % TODO: for a "chunk" size of work, operate on a whole chunk at a
        % time. 
        for n = 1:recon_dims(1)
            current_slice(mask(:))=data(n,:);
            temp_data = abs(ifftn(current_slice./recon_mat.CSpdf)); % 8 May 2017, BJA: Don't need to waste computations on fftshift for scaling calculation
            qq(n)=max(temp_data(:));%quantile(temp_data(:),thresh);
        end
        
        % WARNING: This is not the same as our historical threshold of
        % 0.995. This causes the volume scale to just be the max of the
        % data!
        
        % We will ditch quantile/thresh, since the original code wanted max
        % here.
        %thresh = .999999999;
        %volume_scale = sqrt(recon_dims(2)*recon_dims(3))*quantile(qq,thresh);
        volume_scale = sqrt(recon_dims(2)*recon_dims(3))*max(qq);
        
        optimized_for_memory_time = toc(t_scale_calc);
        log_msg =sprintf('Volume %s: volume scaling calculated in %0.2f seconds.\n',volume_runno,optimized_for_memory_time);
        yet_another_logger(log_msg,log_mode,log_file);
    
    
    end
    % This end pairs with line 143
    clear recon_dims mask;
    % scale data such that the maximum image pixel in zf-w/dc is around 1
    % this way, we can use similar lambda for different problems
    % data is not 0-1.
    
    % BJ (August 2018) Will scale by slice max when the time comes...
    if ~options.slicewise_norm
        data = data/volume_scale;
    end
    
    %mf=matfile(setup_vars,'Writable',true);
    % cant add to vol_mat because its not writeable :D 
    % Lets add to the proper wkspace vol file.
    % vol_mat.volume_scale = volume_scale;
    %% Define auxillary parameters to pass to compiled job
    % %aux_param.maskSize=numel(mask);
    % %aux_param.DN = DN;
    %{
    aux_param.volume_scale=volume_scale;
    
    aux_param.mask=mask;
    aux_param.originalMask=recon_mat.original_mask;
    
    aux_param.TVWeight=options.TVWeight;
    aux_param.xfmWeight=options.xfmWeight;
    
    aux_param.scaleFile=recon_mat.scale_file;
    aux_param.tempFile=temp_file;
    aux_param.volume_log_file = setup_var.volume_log_file;
    %aux_param.totalSlices=recon_dims(1);
    aux_param.original_dims=recon_mat.original_dims;
    aux_param.recon_dims=recon_mat.recon_dims;
    aux_param.waveletDims=wavelet_dims;
    aux_param.waveletType=wavelet_type;
    aux_param.CSpdf=recon_mat.CSpdf;
    %aux_param.originalMypdf=mypdf0;
    aux_param.phmask=recon_mat.phmask;
    if isfield(options,'verbosity')
        aux_param.verbosity=options.verbosity;
    end
%}
    
    %%
    % INIT is wavlet toolbox init function holding the default values
    % param = init;
    % params get globbered each time through the slice wave.
    % SO, NO real value init ing here.
    % param.Itnlim = options.Itnlim;  % Should this be a function of necho?
    
    %% Save common variable file
    if ~exist(setup_var.volume_workspace,'file')
        t_vol_save=tic;
        if isfield(options,'slicewise_norm')
           aux_param.slicewise_norm=options.slicewise_norm; 
        end
        if (options.roll_data)
            disp('Attempting to roll data via kspace...')
            Ny=original_dims(2);
            Nz=original_dims(3);
            ky_profile=(shift_modifier(2)/(Ny))*(1:1:Ny);
            kz_profile=(shift_modifier(3)/(Nz))*(1:1:Nz);
            [Kyy,Kzz]=meshgrid(ky_profile,kz_profile);
            phase_matrix = exp(-2*pi*1i*(Kyy+Kzz));
            original_mask=recon_mat.original_mask;
            phase_vector=phase_matrix(original_mask(:));
            
            data=circshift(data,round(shift_modifier(1)));
            for xx=1:original_dims(1)
                data(xx,:)=phase_vector'.*data(xx,:);
            end
            clear original_mask;
        end
        real_data = real(data);
        imag_data = imag(data);
        % is there a reason the real/imag data re saved here first?
        savefast2(setup_var.volume_workspace,'real_data','imag_data');
        %{
        save(setup_var.volume_workspace,'aux_param','-append');
        save(setup_var.volume_workspace,'param','-append');
        %}
        save(setup_var.volume_workspace,'volume_scale','-append');
        time_to_write_master_mat_file=toc(t_vol_save);
        log_msg =sprintf('Volume %s: master .mat file written in %0.2f seconds.\n',volume_runno,time_to_write_master_mat_file);
        yet_another_logger(log_msg,log_mode,log_file);
    end
end
if (make_tmp)
    %% moved into its own function to facilitate exotic testing.
    logbits.log_mode=log_mode;
    logbits.log_file=log_file;
    CS_allocate_temp_file(recon_mat.original_dims, recon_mat.recon_dims, ...
        logbits, setup_var.work_subfolder, volume_runno, setup_var.temp_file)
end


end
%% internal functions
function [scaling,scaling_time,shift_modifier,first_corner_voxel] = calculate_CS_scaling(current_mask,current_data,mypdf0,n_slices,roll_data)
shift_modifier=[ 0 0 0 ];
% only clip out very noisy voxels (e.g. zippers, artifacts), and not the eyes
% is this equivalent to our old behvior of sorting the whole array,
% and choosing the value 0.005% from the end as our scale target?
% james is COMPLETELY CERTAIN it is not. 
% After extensive discovery on this code, it is clear that a threshold this
% high universally results in a simple img max. 
% Futhermore, we cannot effectively use this value for our later scaling,
% and we may as well take a simple max of the data here. 
% Due to the interwoven nature of this realization, this code has been left
% in place with the "correct" threshold, even though that will still give the max, or
% nearly the max of the data. 
%thresh = .999999999;
thresh = 0.9995;
t_scale_calc=tic;
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
    % 8 May 2017, BJA: Don't need to waste computations on fftshift for scaling calculation
    temp_data = abs(ifftn(current_slice./mypdf0)); 
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
    coeff=1.2;%coeff=1.1; 
    % coeff=> "coeffecient" 
    % a modifier of the min to help us rise above the noise floor. 
    % in the first third of the data finds the last point, which is coeff
    % times bigger than the minimum.
    % lower_min 
    lmin(1)=find((x_sum(1:first_3rd_idx(1))<coeff*x_min),1,'last');
    lmin(2)=find((y_sum(1:first_3rd_idx(2))<coeff*y_min),1,'last');
    l_z=find((z_sum(1:first_3rd_idx(3))<coeff*z_min),1,'last');
    if numel(l_z)~=0
        lmin(3)=l_z;
    else
        % 2D data support, always expect the third dim to be left out.
        lmin(3)=1;
    end
    % in the last third of the data finds the fist point, which is coeff
    % times bigger than the minimum. upper min values are weird becuse
    % their value is not initially 1... volsize big,  
    % rather, 1..(1/3) volsize, to get them expressed in vol_size we must
    % add the last_3rd_idx again (the points we skipped over in calculation).
    % upper_min
    % WARNING: sometimes find returns 0 elements, so used a temp struct 
    % and exotic condensed conditionals are used to overcome that
    % TODO: revisit this, including the why it fails... 
    % we could try/catch this using the old code first, but i'm relatively 
    % confident the new code cant fail, so thats unnecessary clutter. 
    %{
    umin(1)=find((x_sum(last_3rd_idx(1):end)<coeff*x_min),1);
    umin(2)=find((y_sum(last_3rd_idx(2):end)<coeff*y_min),1);
    umin(3)=find((z_sum(last_3rd_idx(3):end)<coeff*z_min),1);
    %}
    %% funny struct find code to prevent 0 element error
    clear umin; % when testing this is important or matlab will be a pain. 
    umin.x=find((x_sum(last_3rd_idx(1):end)<coeff*x_min),1);
    umin.y=find((y_sum(last_3rd_idx(2):end)<coeff*y_min),1);
    umin.z=find((z_sum(last_3rd_idx(3):end)<coeff*z_min),1);
    % potential values for umin are 1.. size(dim)-last_3rd_idx
    d_f=fieldnames(umin);
    for fn=1:numel(d_f)
        if isempty(umin.(d_f{fn}))
            umin.(d_f{fn})=vs(fn)-last_3rd_idx(fn)+1;
        end
    end
    umin=[umin.x,umin.y,umin.z];
    %% 
    umin=umin+last_3rd_idx-1;
    
    new_c=round((umin-lmin)/2+lmin);
    center=new_c-shift_modifier;% adjust new center back for our original position.
    center(center>vs)=center(center>vs)-vs(center>vs);
    first_corner_voxel=center+1-vc;
    first_corner_voxel(first_corner_voxel<0)=first_corner_voxel(first_corner_voxel<0)+vs(first_corner_voxel<0);

    shift_modifier=vc-center; %X seemed almost right, but Y/Z off by half volume

 
%end
scaling_time = toc(t_scale_calc);
scaling = (2^16-1)/q; % we plan on writing out uint16 not int16, though it won't show up well in the database
scaling = double(scaling);
fprintf('CS scale calculation result %g, data will be divided by this value prior to processing, this will hopefully result in a max short int value on completion.\n',scaling);
end
