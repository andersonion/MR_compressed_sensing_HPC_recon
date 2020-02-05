function slicewise_CSrecon_exec(matlab_workspace,slice_indices,setup_variables)
% slicewise_CSrecon_exec(matlab_workspace,slice_indices,setup_variables)
 

if ~isdeployed    
   addpath('/cm/shared/workstation_code_dev/recon/CS_v2/sparseMRI_v0.2/'); 
else
    % for all execs run this little bit of code which prints start and stop time using magic.
    % REQUIRES THE VARIABLE OR IT WONT WORK, We never have to touch the
    % variable again directly. 
    C___=exec_startup();
end

%%%
% This eliminates the nested structure of the incoming slice data, and also writes the each
% slice as they finish instead of waiting until all are done.
%%%
slice_numbers=parse_slice_indices(slice_indices);clear slice_indices;

%% Make sure the workspace file exist
% bleh, this whole construct is clumsy.
log_mode = 3;
log_file ='';
error_flag=0;
if  (~exist(matlab_workspace,'file'))
    error_flag = 1;
    log_msg =sprintf('Matlab workspace (''%s'') does not exist. Dying now.\n',matlab_workspace);
else
    a = who('-file',matlab_workspace,'aux_param');
    if ~size(a)
        %error_flag = 1;
        %log_msg =sprintf('Matlab workspace (''%s'') exists, but parameter ''aux_param'' not found. Dying now.\n',matlab_workspace);
    else
        error_flag = 1;
        log_msg =sprintf('Matlab workspace (''%s'') exists, but legacy parameter ''aux_param'' found. You need to clear work folder and restart recon. Dying now.\n',matlab_workspace);
    end
end
if error_flag==1
    yet_another_logger(log_msg,log_mode,log_file,error_flag);
    % force a quit when deployed, else return broken
    if isdeployed; quit('force'); end
    return;
end; clear error_flag;

%% Load common workspace params
if exist('setup_variables','var')
    if exist(setup_variables,'file')
       % load(setup_variables);
       setup_var=matfile(setup_variables);
       recon_mat=matfile(setup_var.recon_file);
       options=recon_mat.options;
    end
end

if ~exist('options','var')
    error('Trouble loading configuration data, potential data corruption OR attempted restart of previous format work folder');
end
tic
mm = matfile(matlab_workspace,'Writable',false);
%load(matlab_workspace,'aux_param');
%aux_param=mm.aux_param;
% expected params
%{
               mask: [2048x2048 logical]
       originalMask: [1152x1152 logical]
           TVWeight: [0.0012 0.0012 0.0012 0.0012 0.0012]
          xfmWeight: [0.0020 0.0020 0.0020 0.0020 0.0020]
       volume_scale: 2.5173
          scaleFile: '/mnt/civmbigdata/civmBigDataVol/jjc29/S…'
           tempFile: '/mnt/civmbigdata/civmBigDataVol/jjc29/S…'
    volume_log_file: '/mnt/civmbigdata/civmBigDataVol/jjc29/S…'
      original_dims: [1480 1152 1152]
         recon_dims: [1480 2048 2048]
        waveletDims: [12 12]
        waveletType: 'Daubechies'
              CSpdf: [2048x2048 double]
             phmask: [2048x2048 double]
          verbosity: 0
%}
%load(matlab_workspace,'param');
%param=mm.param;
%{
fieldnames(test_m.param)
                  FT: []
                 XFM: []
                  TV: []
                data: []
            TVWeight: 0.0100
           xfmWeight: 0.0100
              Itnlim: 50
            gradToll: 1.0000e-30
            l1Smooth: 1.0000e-15
               pNorm: 1
    lineSearchItnlim: 150
     lineSearchAlpha: 0.0100
      lineSearchBeta: 0.6000
        lineSearchT0: 1
%}
param=init;
time_to_load_common_workspace=toc;
if isdeployed
    log_mode = 1;
else
    % when not deployed the log printing takes significant time.
    log_mode=2;
end;
log_file = setup_var.volume_log_file;

log_msg =sprintf('Time to load common workspace: %0.2f seconds.\n',time_to_load_common_workspace);
yet_another_logger(log_msg,log_mode,log_file)

%% Setup common variables
%mask_size=aux_param.maskSize;
%DN=aux_param.DN;
% mask=aux_param.mask;
% TVWeight=aux_param.TVWeight;
% xfmWeight=aux_param.xfmWeight;
% volume_scale=aux_param.volume_scale;
% temp_file=aux_param.tempFile;
% recon_dims=aux_param.recon_dims;
recon_dims=recon_mat.recon_dims;
% CSpdf=aux_param.CSpdf; % We can find the LESS THAN ONE elements to recreate original slice array size
% phmask=aux_param.phmask;
%{
wavelet_dims=aux_param.waveletDims;
if isfield(aux_param,'waveletType')
    wavelet_type=aux_param.waveletType;
else
    wavelet_type = 'Daubechies';
end
%}

OuterIt=length(options.TVWeight);
if length(options.xfmWeight) ~= OuterIt
    error('Outer iterations determined by length of xfmWeight and TVWeight, Error in setting!');
end

options=recon_mat.options;
XFM = Wavelet(options.wavelet_type,options.wavelet_dims(1),options.wavelet_dims(2));

param.XFM = XFM;
param.TV=TVOP    ;
%% set special options of the BJ fnlCg_verbose function
recon_options=struct;
    %{
if ~isdeployed
    recon_options.verbosity = 1;
    recon_options.log_file = log_file;
    recon_options.variable_iterations = 1;
else
    %}
    if exist('variable_iterations','var')
        recon_options.variable_iterations = variable_iterations; end
    if exist('volume_log_file','var')
        recon_options.log_file=volume_log_file; end
    if exist('log_mode','var')
        recon_options.log_mode = log_mode; end
    if exist('verbosity','var')
        recon_options.verbosity=verbosity; end
    if exist('make_nii_animation','var')
        recon_options.make_nii_animation = make_nii_animation; end
    if exist('convergence_limit','var')
        recon_options.convergence_limit=convergence_limit; end
    if exist('convergence_window','var')
        recon_options.convergence_window=convergence_window; end
% end
%%
% requested_iterations = param.Itnlim;
requested_iterations = options.Itnlim;
%im_result=zeros(dims(2),dims(3),length(slice_numbers));
%header_size = dims(1);
%header_size = dims(1)*64;% 8 May 2017, BJA: Change header from binary to local scaling factor
%header_size = dims(1)*16;% 15 May 2017, BJA: Change header from local scaling factor to number_of_completed_iterations
header_size = 1+recon_dims(1);% 26 September 2017, BJA: 1st uint16 bytes are header length, + number of x slices of uint16 bits
%% Reconstruct slice(s)
for index=1:length(slice_numbers)
    slice_index=slice_numbers(index);
    %% read temp_file header for completed work.
    % this could be done exactly once before looping foreach slice.
    t_id=fopen(setup_var.temp_file,'r+');
    % Should be the same size as header_size 
    header_length = fread(t_id,1,'uint16'); 
    % 15 May 2017, BJA; changed header from double to uint16; will indicate number of iterations performed
    %work_done = fread(fid,dims(1),'*uint8');
    work_done = fread(t_id,header_length,'uint16');
    % 8 May 2017, BJA: converting header from binary to double local_scaling
    %work_done = fread(fid,dims(1),'double'); 
    fclose(t_id);
    %% decide if we're continuing work or not
    continue_work = 0;
    completed_iterations = work_done(slice_index);
    % completed_iterations formerly previous_Itnlim(and c_work_done)
    if (completed_iterations > 0);
        %previous_Itnlim = floor(c_work_done/1000000); % 9 May 2017, BJA: Adding ability to continue CS recon with more iterations.
        if (requested_iterations > completed_iterations)
            param.Itnlim = requested_iterations - completed_iterations;
            % current_Itnlim/re_inits 
            continue_work=1;
            log_msg =sprintf('Slice %i: Previous recon work done (%i iterations); continuing recon up to maximum total of %i iterations.\n',slice_index,completed_iterations,requested_iterations);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    else
        % requested is the max n of iterations, ignoring re-init's
        % re-initalizaiton is not compatible with keep work for now. 
        % I think we need a conditional of when outerIT>1
        % I think we say, requested_iterations/outerit.
        % completed mod interval, not to worry we dont save partial blocks.
        % current_Itnlim/OuterIt
        
        param.Itnlim= requested_iterations / OuterIt;
        if mod(requested_iterations,OuterIt)>0 
            error('re_init error,total_it %g not even division of %g',requested_iterations,OuterIt);
        end
    end
    
    if ((completed_iterations == 0) || (continue_work)) %~work_done(slice_index)
        %% Load slice specific data
        
        load_start=tic;
        
        if (completed_iterations == 0) 
            %slice_data = complex(double(mm.real_data(slice_index,:)),double(mm.imag_data(slice_index,:)) );% 8 May 2017, BJ: creating sparse, zero-padded slice here instead of during setup
            slice_data = complex(mm.real_data(slice_index,:),mm.imag_data(slice_index,:));
            param.data = zeros(size(recon_mat.mask),'like',slice_data); % Ibid
            %param.data = zeros([size(mask)],'like',slice_data);
            param.data(recon_mat.mask)=slice_data(:); % Ibid
            
            time_to_load_sparse_data = toc(load_start);
            log_msg =sprintf('Slice %i: Time to load sparse data:  %0.2f seconds.\n',slice_index,time_to_load_sparse_data);
            yet_another_logger(log_msg,log_mode,log_file);
            
            % this compensates the intensity for the undersampling
            % experimented with removing this volume scale and found that
            % destroyed the output. 
            % according to the original code comments im_zfwdc should be
            % 0-1 for the whole volume, take care checking here as this is
            % slice at a time. 
            % presumably pdf is point density function. We could instead
            % use the CS Mask to get the actual density instead of the 
            % the theoretical. We have sdc3_mat, we've used before.
            % https://github.com/ISMRM/mri_unbound
            im_zfwdc = ifft2c(param.data./recon_mat.CSpdf)/mm.volume_scale;
            ph = exp(1i*angle((ifft2c(param.data.*recon_mat.phmask))));
            param.FT = p2DFT(recon_mat.mask, recon_dims(2:3), ph, 2);
            res=XFM*im_zfwdc;
            clear im_zfwdc ph slice_data; 
        else
            % James says: convergence_window is only added after we've done some work.
            % Is that the behavior we want?
            % BJ says: no, what is happening here is that the convergence
            % window is being reduced from its default of 10 to 3 when work
            % is reinitialized.  But the whole convergence algorithm is
            % questionable anyways (at least how implemented by me).
            recon_options.convergence_window = 3;
            
            res=CS_tmp_load(setup_var.temp_file,recon_dims,slice_index);
  
        end
         
        time_to_set_up = toc(load_start);
        log_msg =sprintf('Slice %i: Time to set up recon:  %0.2f seconds.\n',slice_index,time_to_set_up);
        yet_another_logger(log_msg,log_mode,log_file);
        
        %% iterate OuterIt times "inner It" passed in param as Itnlim
        iterations_performed=0;
        time_to_recon=0;
        for n=1:OuterIt
            if OuterIt>1
                yet_another_logger(...
                    sprintf('\t %i iter block # %i\n',param.Itnlim,n),log_mode,log_file);
            end
            % gotta be sure these are 1xN
            param.TVWeight  = options.TVWeight(n);   % TV penalty
            param.xfmWeight = options.xfmWeight(n);  % L1 wavelet penalty
            [res, inner_its, lin_search_time] = fnlCg_verbose(res, param,recon_options);
            time_to_recon=time_to_recon+lin_search_time;
            iterations_performed=iterations_performed+inner_its;
        end
        
        log_msg =sprintf('Slice %i: Time to reconstruct data (With %i iteration blocks):  %0.2f seconds. \n',slice_index,n,time_to_recon);
        yet_another_logger(log_msg,log_mode,log_file);
        if ~isdeployed && strcmp(getenv('USER'),'rja20')
            
            %% Plotting today BJ?
            scale_file=aux_param.scaleFile;
            fid_sc = fopen(scale_file,'r');
            scaling = fread(fid_sc,inf,'*float');
            fclose(fid_sc);
            im_res = XFM'*res;
            im_res = im_res*mm.volume_scale/sqrt(recon_dims(2)*recon_dims(3)); % --->> check this, sqrt of 2D plane elements required for proper scaling
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
            
        end % Plotting today BJ?

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
        
        t_id=fopen(setup_var.temp_file,'r+');
        header_length = fread(t_id,1,'uint16'); % Should be the same size as header_size
        work_done = fread(t_id,header_length,'uint16');
        %% Write data
        if (~work_done(slice_index) || ((continue_work) ...
                && (work_done(slice_index) < requested_iterations)))
            s_vector_length = recon_dims(2)*recon_dims(3);
            data_offset=(2*8*s_vector_length*(slice_index-1));
            fseek(t_id,data_offset,0);
            % switched out these two lines for a one liner to reduce mem overhead.
            % image_to_write = [real(res(:))' imag(res(:))'];
            % fwrite(t_id,image_to_write,'double'); %'n'
            fwrite(t_id,[real(res(:))' imag(res(:))'],'double');
            log_msg =sprintf('Slice %i: Successfully reconstructed and written to %s.\n',slice_index,setup_var.temp_file);
            if log_mode==2
                yet_another_logger(log_msg,1,log_file);
            else
            yet_another_logger(log_msg,log_mode,log_file);
            end
            % Write header
            %fseek(fid,(slice_index-1),-1);
            header_info = uint16(completed_iterations+iterations_performed);
            %fseek(fid,8*(slice_index-1),-1); % 8 May 2017, BJA: changing header from binary to double local_scaling factor.
            %fseek(fid,2*(slice_index-1),-1); % 15 May 2017, BJA: header stores number of iterations now
            
            num_written=0;
            for tt=1:30 %% is this a 30 retry count for write?
                fseek(t_id,2*(slice_index),-1); %Need to account for the first two bytes which store header length.
                num_written=fwrite(t_id,header_info,'uint16'); % 15 May 2017, BJA: see directly above
                if (num_written ~= 1)
                    pause(0.05)
                else
                    break
                end
            end
            if (num_written ~= 1) 
                log_msg =sprintf('Slice %i: Reconstruction flag ("%i") WAS NOT written to header of %s, after %i tries.\n',...
                    slice_index,header_info,setup_var.temp_file,tt);
                yet_another_logger(log_msg,log_mode,log_file,1);
                variable_that_throws_an_error_so_slurm_knows_we_failed;
                error('would slurm see this slice error?');
            else
                log_msg =sprintf('Slice %i: Reconstruction flag ("%i") written to header of %s, after %i tries.\n',...
                    slice_index,header_info,setup_var.temp_file,tt);
            end
            yet_another_logger(log_msg,log_mode,log_file);
            
            time_to_write_data=toc;
            log_msg =sprintf('Slice %i: Time to write data:  %0.2f seconds.\n',slice_index,time_to_write_data);
            yet_another_logger(log_msg,log_mode,log_file);
        end
        fclose(t_id);
    else
        log_msg =sprintf('Slice %i: Previously reconstructed; skipping.\n',slice_index);
        yet_another_logger(log_msg,log_mode,log_file);
    end
end

%% 31 August 2018, BJ says: using code from volume cleanup to check if the
%  slices in this job will appear to be reconned then; if any have failed,
%  will explicitly fail in hopes of triggering backup jobs instead of
%  another complete cycle of volume_manager, etc.
[~,~,tmp_header] = read_header_of_CStmp_file(setup_var.temp_file);
apparent_iterations = tmp_header(slice_numbers);
apparent_failures = slice_numbers(apparent_iterations<requested_iterations);
num_af=length(apparent_failures);
if  (num_af > 0)
    %error_flag=1; % BJ says: I'm honestly not even sure where all our
    %error logs are ending up at...it reminds of the messages in the
    %tubes in Lost.
    for ff = 1:num_af
        log_msg =sprintf('Slice %i: attempted reconstruction appears to have failed; THROWING FAILURE FLAG.\n',apparent_failures(ff));
        yet_another_logger(log_msg,log_mode,log_file);
    end
    
    status=variable_to_force_an_error;
    
end
%%
return

end
function slice_numbers=parse_slice_indices(slice_indices)
% slice numbers pulled down to its own function to remove temp vars from workspace easier. 
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
end
