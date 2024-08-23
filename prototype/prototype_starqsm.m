function prototype_starqsm(echo_dirs,workpath,out_qsm,varargin)

prototype_starqsm_path();
start_dir=pwd;
C__ = onCleanup(@() cd(start_dir));

if numel(varargin)
    mask_file=varargin{1};
    if ~iscell(mask_file)
        assert(exist(mask_file,'file'),'Missing specified mask file: %s',mask_file);
    else
        assert(all(cellfun(@(x) exist(x,'file'),mask_file)), ...
            'Missing one of the specified mask files:\n\t%s',strjoin(mask_file,'\n\t'));
    end
end

% MASKING IMPORTANT FOR GOOD RESULT!
skip_mask=0;
verbosity=0;
must_raw=1; 

if ~exist(workpath,'dir')
    mkdir(workpath);
end
chdir(workpath);

default_out='star_qsm.nii';
if exist(default_out,'file')
    gzcur=0;
    cur=default_out;
elseif exist([default_out '.gz'],'file') 
    gzcur=1;
    cur=[default_out '.gz'];
end
gzout=reg_match(out_qsm,'gz$');
if exist('cur','var')
    if gzcur && ~gzout
        out_qsm=[out_qsm '.gz'];
    elseif ~gzcur && gzout
        out_qsm=regexprep(out_qsm,'.gz$','');
    end
    movefile(cur,out_qsm);
end
if exist(out_qsm,'file')
    %{
    star_qsm=open_nii('star_qsm');
    show3(star_qsm);
    %}
    warning('%s complete',out_qsm);
    return;
end
out_qsm=regexprep(out_qsm,'.gz$','');

%echo_dirs=regexpdir(datapath,[runno 'c_m[0-9]+/?$'],0);
[raw,hfs]=load_4d(echo_dirs{:});
runno1=hfs{1}.U_runno;
res=[hfs{1}.fovx,hfs{1}.fovy,hfs{1}.fovz]./[hfs{1}.dim_X,hfs{1}.dim_Y,hfs{1}.dim_Z];
nechoes=numel(echo_dirs);
echos=hfs{1}.z_Agilent_TE;
if numel(echos)~=nechoes
    warning('echo count doenst match attempting to use runno _m[0-9]+ formatting to select from echo array.')
    runnos=cell(size(hfs));
    for r_idx=1:numel(runnos)
        runnos{r_idx}=hfs{r_idx}.U_runno;
    end
    t=regexpi(runnos,'_m([0-9]+)$','tokens');
    echo_indicies=zeros(size(t))-1;
    for r_idx=1:numel(runnos)
        echo_indicies(r_idx)=str2double(t{r_idx}{1});
    end
    echo_indicies=echo_indicies+1;
    echos=echos(echo_indicies);
end
assert(numel(echos)==nechoes)
TE_ms = echos;
TE_s = TE_ms/1000;

% get back to kspace, 1. fft, 2. fftshift.
% these two methods produce identical results. One may be faster/use less
% memory, requires testing.
raw3=raw;
for e=1:nechoes
    raw3(:,:,:,e)=fftshift(fftn(raw(:,:,:,e)));
end
%{
disp_vol_center(raw3,1,200);
disp_vol_center(angle(raw3),1,210);
%}

%{
raw2=fft(fft(fft(raw,[],1),[],2),[],3);
raw2=fftshift(fftshift(fftshift(raw2,1),2),3);
disp_vol_center(raw2,1,220);
disp_vol_center(angle(raw2),1,230);
raw=raw2;clear raw2;
%}

raw=raw3;clear raw3;
%  kspc=raw;
vox=res; save vox vox; clear res;
%%
%
% WAWRNING: run-rerun variability, a re-loaded mag will be single precision
% but a fresh recon mag will be double! (hopefully that doesn't matter)
%
if ~exist('mag.nii','file')||must_raw
    % now in kspace.
    [raw,phase_shift]=phase_ramp_remove1(raw);
    %  kspc2=raw;
    save phase_shift phase_shift;
    % This code right here, flips the data WRONG and reshuffles echoes.
    % in conjunction with getting the imgspce -> kspace wrong above!
    %raw = iftME(raw);
    %% run ifftME in line, which is a 3D centered fft if the code stack is to be believed.
    magic_number=sqrt( prod( size(raw,1:3) ) );
    for e=1:nechoes
        raw(:,:,:,e)=magic_number*ifftn(ifftshift(raw(:,:,:,e)));
    end
    % autoC is auto-centering, this is MORE prmitive than our typical centering
    % which finds BOTH minimums near the volume edge, and centers the data
    % between them.
    [raw,shift_vector] = autoC(raw); save shift_vector shift_vector;
    mag=abs(raw);
    mat2nii(mag)
else
    mag=open_nii('mag');
end
%show3(mag(:,:,:,1));
%
%%
if ~exist('R2.nii','file')
    % WARNING: t2 will later be replaced by running this function again
    % providing the mask
    warning('Choosing to skip this becuase T2 will be replaced anyway, and R2 is not used in this function');
    %{
    % note, R2 looked like hell when it was checked... maybe mask required?
    % so this shouldn't be done at all until then?
    [T2,R2]=T2mapMaskedWeighted(mag,TE_s);
    mat2nii(T2);
    mat2nii(R2);
    clear T2 R2;
    %}
end
if ~exist('raw.mat','file')
    warning('SKIP SAVING mat_format raw becuase its slower than re-calculating!');
    %save raw raw -v7.3
end

%% mask generation
%trying to skip!
%tic
use_strip_mask_exec=true;
if ~skip_mask && exist('mask_file','var') 
    if ~iscell(mask_file)
        [mask,mhdr]=read_civm_image(mask_file,1);
    else
        [mask,mhdrs]=load_4d(mask_file{:});
        mhdr=mhdrs{1};
    end
    if phase_shift~=0 || any(shift_vector)
        % by testing it looks like phase_shift not needed....
        mask_shift=shift_vector;%+phase_shift;
        mask=circshift(mask,mask_shift);
        %{
% test mask adjustment
        t=raw;
        for eidx=1:nechoes
            v=t(:,:,:,eidx);
            v(mask==0)=0;
            t(:,:,:,eidx)=v;
        end;clear eidx;
        disp_vol_center(t)
        %}
    end
end
if ~skip_mask && ~exist('mask','var')
    if ~exist('mag_sos.nii','file') && ~exist('msk.nii.gz','file')
        % additional step for mag_sos (sum of squares?)
        %% inline method
        % inline may be better on memory/time.
        mag_sos=mag.^2;
        mag_sos=sum(mag_sos,4);
        mag_sos=sqrt(mag_sos);
        mag_sos=single(mag_sos);
        %% loop method
        %{
        vdim=size(raw);vdim=vdim(1:3);
        mag_sos = zeros(vdim);
        for echo_num = 1:size(raw,4)
            mag_sos = (abs(raw(:,:,:,echo_num))).^2 + mag_sos;
        end
        mag_sos = sqrt(mag_sos);
        %}
        mat2nii(mag_sos);
        % show3(mag_sos);
    elseif exist('mag_sos.nii','file')
        %mag_sos=load_niigz('mag_sos.nii');mag_sos=mag_sos.img;
        mag_sos=open_nii('mag_sos');
    end
    if ~exist('msk.nii.gz','file') && use_strip_mask_exec
        % strip_mask_exec('mag_sos16.nii',1,-2,'mask_u16.nii',12,2.5,2);
        if ~exist('mag_sos16.nii','file')
            mag_sos16=scale_data(mag_sos,2^16-1);
            mag_sos16=cast(mag_sos16,'uint16');
            mat2nii(mag_sos16);
        end
        % these mask params probably would change for different voxel size.
        % This was civm-9t at 25um for the TEST_FISTA dataset.
        %{
        strip_mask_exec('mag_sos16.nii',1,-2,'msk.nii',12,1.9,verbosity);
        strip_mask_exec('mag_sos16.nii',1,-2,'msk.nii',15,1.9,verbosity);
        strip_mask_exec('mag_sos16.nii',1,-2,'msk.nii',13,2.1,verbosity);
        strip_mask_exec('mag_sos16.nii',1,-2,'msk.nii',13,2.3,verbosity);

        strip_mask_exec('mag_sos16.nii',1,-2,'msk_20_1p7.nii',20,1.7,verbosity);
        strip_mask_exec('mag_sos16.nii',1,-2,'msk_25_1p7.nii',25,1.6,verbosity);
        strip_mask_exec('mag_sos16.nii',1,-2,'msk_5_3p0.nii',5,3,verbosity);

        %}
        %{
        %%% make a par-for param-set so we can parallel the whole problem
        %%% space.
        iters=5:2:25;
        radii=2.7:.3:5;
        % reduce to first last for rapid testing.
        iters=5 : (25-5) : 25;
        radii=0.7 : (3 - .7) : 3;
        param_set=cell(prod([numel(iters),numel(radii)]), 1);
        p=1;
        for iter=iters
            for r=radii
                param_set(p)={[r,iter]};
                p=p+1;
            end
        end
        parfor p=1:numel(param_set)
            r=param_set{p}(1);
            iter=param_set{p}(2);
            ri=floor(r);
            f=floor(10*(r-ri));
            mout=sprintf('msk_%ip%i_%i.nii',ri,f,iter);
            disp(mout);
            strip_mask_exec('mag_sos16.nii',1,-2,mout,iter,r,0);
        end
        %}

        % for the new test data set, default params work.
        strip_mask_exec('mag_sos16.nii',1,2,'msk.nii',[],[],verbosity);
        [s,sout]=system(sprintf('gzip -9 %s','msk.nii'));
        assert(s==0,sout);
    elseif ~exist('msk.nii.gz','file')     
        % brainext inputs are data_vol, threshold_zero, threshold
        % multiplier
        % its rather funny to choose a higher threhold zero, and then
        % reduce the threshold multiplier... but this is the state i found
        % this in. In testing these two calls are just about literally
        % identical AND leave too much non-brain behind!
        % brainext(mag_sos,3,0.45);
        % brainext(mag_sos,2,0.65);
        % moving this up, and intentioanlly removing a bit more to help the
        % qsm.
        try
            brainext(mag_sos,3,1.3);
        catch
            brainext(mag_sos);
        end
        disp('Threshold Mag SOS in ImageJ then combine with scripted msk')
    end
    %%
    if ~exist('msk_comb.nii.gz','file')
        mask = open_nii('msk');
        save_comb_mask=0;
        try
            msk_thresh = open_nii('msk_thresh');
            mask_comb = mask.*msk_thresh;
            save_comb_mask=1;
            mat2nii(mask_comb);
            mask=mask_comb; clear mask_comb;
        catch
            warning('no mask_comb, just using small mask');

            % msk_comb=msk;
        end
    end
end

%% QSM Recon Pipe
% Input
% raw - double precision complex imagesspace
%       That is what is hiding in our cs qsm tmp .mat files
% mask - 8-bit brain only mask saved to msk_comb.nii.gz
% TE - array of TE
% vox - array of voxelsize
% Determine SNR and calculate T2 map
if ~exist('mask','var') && ~skip_mask
    mask = load_nii('msk_comb.nii.gz');
    mask = single(mask.img);
end
if ~exist('meanSNR.mat','file')
    if ~exist('mask','var')
        autoSNR(mag);
    else
        autoSNR(mag,mask);
    end
end
load('meanSNR');
if skip_mask
    mask=ones(size(mag),'single');
end
% these should already be in memory from above.
% load('TE.mat') % array with echo times such as TE = [0.04 0.08 ...]
% load('vox.mat') % array with voxel size in each dimension such as vox = [0.1 0.1 0.1]

% before img had been converted to magnitude
%T2 = T2mapMaskedWeighted(img(:,:,:,1:4),TE(1:4),mask,meanSNR(1:4));
% confusingly, we've already run this function and saved an image called
% T2.nii, difference here is that we've also provided the mask and meanSNR
% inputs to the function
T2 = T2mapMaskedWeighted(mag,TE_s,mask,meanSNR);
% save_nii(make_nii(T2),'T2.nii');
mat2nii(T2);

% clear all;
clear R2 T2 msk msk_comb

%% QSM
% prep
prepad = 1;
%nprepad = 16;
nprepad = 12;
prepadsize = [nprepad nprepad nprepad]; % performed by Wei's scripts
padsize = 2; %boundary left by autocrop for speed
% phi = angle(open_nii('img.nii'));
tic
%load dims % array with dimensions of raw img ex. dims = [256 256 256 4]
%load TE
raw_img_file = 'img.nii';
if ~exist('maskE.nii','file') 
    if ~skip_mask
        %mask = open_nii('msk_comb');
        mask = imdilate(mask,strel3d(2));
        mask = imerode(mask,strel3d(2));
        % NOT saving the erroded mask!
        % save_nii(make_nii(mask,[1 1 1],[0 0 0],2),'maskE.nii');
    end
else
    mask=open_nii('maskE');
end
%autocrop(mask,padsize);
toc

% Calculate unwrapped and filtered phase

warning('hard coding B0 and H field');
%B0 = 3.0; H = [1 0 0]; % define B0 and direction of main field H
if runno1(1) == 'N'
    % agilent 9t
    B0 = 9.4; H = [0 0 1];
elseif runno1(1) == 'S'
    % agilent 7t
    B0 = 7.0; H = [0 0 1];
else
    warning('guess of field strength not available, set manually right now, also warnings have been forced to dbstop, clear that if you want.');
    dbstop if warning;
    dbstop if error;
    keyboard
end
niter = 50;
%%

%idx = 1:dims(4)
%idx = 1:2
combinedX_flag = 1;
X_flag = 1;

% Freq = zeros([dims(1:3) 8],'single');
% manually set num echos to use: 3
% Freq = zeros([dims],'single');
 
% TE from here forward needs to be in MS
% have switched to keeping TE_s and TE_ms to reduce confusion
% if TE(1) < 1
%     TE = procpar.TE; % s -> ms
% end
%disp(TE_s);
%disp(TE_ms);
back = 0; time = 0;

TissuePhase_all=zeros(size(raw),'single');
Freq_v=zeros(size(raw),'single');
for e = 1:nechoes
    [back,time] = progress(e,nechoes,'Phase unwrap and V_SHARP per echo',back,time);back=0;
    % if necho <= size(mask,4)
    %     mask2 = applyautocrop(single(mask(:,:,:,necho)));
    % else
    %     mask2 = applyautocrop(mask(:,:,:,1));
    % end
    if e <= size(mask,4)
        mask2 = single(mask(:,:,:,e));
    else
        mask2 = single(mask(:,:,:,1));
    end
    if exist('Freq_v.nii.gz','file') || exist('Freq_v.nii','file')
        continue;
    end
    ScalingCoeff = ScalingFactor(B0,TE_ms(e));
    if ScalingCoeff.Freq == 0
        msg='ScalingCoeff calc failed! Freq is 0!';
        db_inplace(mfilename,msg);
        warning(msg);
    end
    
    %TissuePhase = iHARPERELLA(applyautocrop(single(angle( ...
    %open_nii(raw_img_file,necho)))),mask2,'padsize',prepadsize);
        
    % raw_img_file was NOT present!
    %%one_echo=open_nii(raw_img_file,necho);
    % NOT certain that raw is the same here!
    % however, the output looks correct.
    one_echo=squeeze(raw(:,:,:,e));
    UnwrapPhase = LaplacianPhaseUnwrap( ...
        (single(angle(one_echo))),'padsize',prepadsize);
    if nnz(UnwrapPhase)==0
        msg='LaplacianPhaseUnrwarp failed! all elements 0';
        db_inplace(mfilename,msg);
        warning(msg);
    end
    %%%
    %%% WARNING WARNING WARNING! TissuePhase result will change based on
    %%% mask, but it is not clear how!
    %%%
    TissuePhase = V_SHARP(UnwrapPhase,single(mask2),'padsize',prepadsize);
    if nnz(TissuePhase)==0
        msg='V_SHARP failed! all elements 0';
        db_inplace(mfilename,msg);
        warning(msg);
    end
    TissuePhase_all(:,:,:,e) = TissuePhase;
    Freq_v(:,:,:,e) = (TissuePhase)*ScalingCoeff.Freq;
    %figure;imshow(Freq_v(:,:,160,necho),[])
    %drawnow;
end
if ~exist('Freq_v.nii','file') && ~exist('Freq_v.nii.gz','file')
    mat2nii(Freq_v);
    % mat2nii(UnwrapPhase)
    mat2nii(TissuePhase_all)
    clear UnwrapPhase TissuePhase TissuePhase_all
end

%% Combine echoes to enhance images and save results in Nifti format.

% statmask = HeartT2Mask('mag.nii',1,2);
% mat2nii(statmask);
if ~exist('MEWeight.mat','file')
    % First acquire T2* information
    % T2mask = open_nii('statmask');
    % T2mask = open_nii('maskE');
    T2mask = mask;
    T2mask(T2mask ~= 1) = 0;
    % T2file = dir('T2*.nii');
    % T2 = open_nii(T2file.name);
    T2 = open_nii('T2');
    T2pix = T2(logical(T2mask(:,:,:,1)));
    T2pix(isinf(T2pix)) = [];
    T2pix(isnan(T2pix)) = [];
    T2pix(T2pix == 0) = [];
    T2vec = .001:.001:.1;
    ncounts = histc(T2pix,T2vec);
    figure(4392); plot(T2vec,ncounts);
    [~,T2idx] = max(ncounts);
    meanT2 = T2vec(T2idx);
    save MEWeight meanT2
else
    load MEWeight
end
clear T2 T2pix TissuePhase maskE2 raw T2mask
warning('THIS WAS FORCED TO MAX OF 2 ECHOS PREVIOUSLY.')
max_echo = 2;
max_echo = nechoes;
% meanT2 = open_nii('T2');
% combine frequency data
if ~exist('FreqC_v.nii.gz','file') && ~exist('FreqC_v.nii','file')
    [~,FreqC_v] = nanMEW(TE_ms(1:max_echo)/1000,meanT2,Freq_v(:,:,:,1:max_echo));
    if nnz(FreqC_v)==0
        error('nanMEW failed and generated a 0 volume');
    end
    mat2nii(FreqC_v);
else
    FreqC_v=open_nii('FreqC_v');
end
clear Freq_v

%% Star QSM
if ~exist([default_out '.gz'],'file') && ~exist(default_out,'file') ...
    && ~exist([out_qsm, '.gz'],'file') && ~exist(out_qsm,'file')
    %QSM_star = QSM_STI_Star(FreqC_v,single(mask2),9.4,[0 0 1],[1 1 1],[12 12 12],10,0.6);
    FreqC_v_sc = FreqC_v/ (1./mean(TE_ms(1:max_echo))./2./pi)*2*pi/1000;
    star_qsm = QSM_star(FreqC_v_sc ,single(mask2),'H',H, 'voxelsize',vox,'padsize', prepadsize,'TE',mean(TE_ms(1:max_echo)),'B0',B0,'tau',0.000001);
    %star_qsm = star_qsm*2*pi/1000;
    mat2nii(star_qsm);
end
if exist(default_out,'file')
    movefile(default_out,out_qsm);
end
close all;

