%% pull the data and create raw image
function prototype_qsm_cs_workdir(runno)
% rad_mat('heike','N56315','N56275_02/ser53.fid');  %%%%DTI NO fermi filter
C__ = onCleanup(@() cd(pwd));
% w2bart, wbart, CS_v3, CS_v2, CS_v1
% w == wyatt.
cs_code_selection='w2bart';
% reset for new test data where we have fetched from archive.
% To fit the old data setuo to get started, a CS_v2 recon work folder was
% copied from RUNNO.work to RUNNO
% hard links were created from fid to RUNNO.fid
% and procpar to RUNNO.procpar
use_new_CS=1;
% MASKING IMPORTANT FOR GOOD RESULT!
skip_mask=0;

%% old fashioned get data from scanner out of use
if strcmp(cs_code_selection,'w2bart')
    BD=getenv('BIGGUS_DISKUS');
    if ~exist('runno','var') || strcmp(runno,'test') || ~exist(runno,'dir')
        project='test';
        runno='MGRE_BART';
        runno='MGRE_FISTA';
        spec='spec';
        qsm_work=sprintf('%s_qsm',runno);

        folder_parts={BD,[project '.work'],spec,runno};
        datapath=fullfile(folder_parts{:});
        folder_parts{end}=qsm_work;
        workpath=fullfile(folder_parts{:});

    elseif exist(runno,'dir')
        datapath=runno;
        [p,runno,e]=fileparts(runno);
        workpath=fullfile(p,[runno '_qsm']);
    end
    

elseif strcmp(cs_code_selection,'CS_v1')
    % scanner = 'kamy';
    % runno = 'S66730';
    % study = 'S66730_01';a
    % series = 'ser13';
    % rad_mat('heike','N56302','N56275_02/ser12.fid',{'skip_filter'});  %%%%GRE
    scanner = 'kamy';
    %runno = 'S69054s';
    study = 'S200221_05';
    series = 'ser49';
    %runno = 'S69240';
    study='localdata';
    series='localseries';
    % workpath returned by agilent2nas4(and similar
    % scripts) it is a old format CS recon folder.
    %workpath = agilent2glusterspace_k(scanner,runno,study,series,'o');
    workpath=fullfile(getenv('BIGGUS_DISKUS'),runno );
    if ~exist(workpath,'dir')
        workpath = agilent2nas4_k(scanner,runno,study,series);
    end
    cd(workpath);
end
if reg_match(cs_code_selection,'w2?bart')
    % WARNING changing the meaning of workpath to be my QSM workpath!
    if ~exist(workpath,'dir')
        mkdir(workpath);
    end
    chdir(workpath);
    %
else
    % new CS_v2 data format, had to be run with keep_work option to be useful
    workpath=fullfile(getenv('BIGGUS_DISKUS'),[runno '.work']);
    %workpath='/mnt/duhsnas-pri.dhe.duke.edu/civm-projectdata/jjc29/clusterscratch/S69222.work'
    cd(workpath);
    if ~exist('qsm','dir')
        mkdir('qsm');
    end
    cd('qsm');
end

if exist('star_qsm.nii.gz','file') || exist('star_qsm.nii','file')
    warning('%s complete',workpath);
    return;
end

%% example to load CS data
must_raw=1; %% somehow be nice to hold onto the "raw" data instead of re-calculating.
%% old fashioned get data from scanner out of use
if strcmp(cs_code_selection,'w2bart')
    echo_dirs=regexpdir(datapath,'.*m[0-9]+',0);
    echo_images=cell(size(echo_dirs));
    e=0;
    for d=echo_dirs(:)'
        cfl_path=regexpdir(d{1},'.*[.]cfl',0);
        [p,n,~]=fileparts(cfl_path{1});
        e_cfl=readcfl(fullfile(p,n));
        echo_images(e+1)={e_cfl};
        e=e+1;
    end
    echo_file=regexpdir(datapath,'echo_times_ms.txt');
    echo_file=echo_file{1};
    echos=csvread(echo_file);
    voldims=size(echo_images{1});
    % fov
    res=[0.025,0.025,0.025];
    nechoes=numel(echos);
    TE_ms = echos;
    TE_s = TE_ms/1000;
    raw=cell2mat(echo_images);
    raw=reshape(raw,[voldims(1),4,voldims(2),voldims(3)]);
    raw=permute(raw,[1,3,4,2]);
elseif reg_match(cs_code_selection,'CS_v[23]')
    procpar=readprocpar(fullfile(workpath,'procpar'));
    if ~exist('mag.nii','file')||must_raw
        raw=load_imagespace_from_CS_tmp(workpath);
    end
    %disp_vol_center(raw(:,:,:,1))
    %vars=matfile([runno 'recon.mat']);
    voldims=[procpar.np/2 procpar.nv procpar.nv2];
    % not-valid becuse CS
    %nvols=(npoints/2*ntraces*nblocks)/prod(voldims);
    %blocks_per_vol=nblocks/nvols;
    fov=[procpar.lro procpar.lpe procpar.lpe2].*10; %fov in mm this may not be right for multislice data
    res=fov./voldims;
    if exist('procpar','var')
        nechoes = numel(procpar.TE);
    else
        nechoes = 1;
    end
    TE_ms= procpar.TE;
    TE_s = procpar.TE/1000; 
    %dims = [voldims nechoes];
elseif exists('cartesean_sample_example','var')
    %% this was written for NON-CS data!
    % AND has not been updated for adjustments made to other parts of the
    % script!(sorry)
    mkdir ser12
    cd ser12
    save fov fov
    vox = res; save vox vox
    TE = procpar.TE/1000; save TE TE
    dims = [voldims nechoes]; save dims dims
    
    load([runno 'recon.mat']);
    % phase ramp removal
    load_fid_ME_wrapper4;
    raw=readMEraw('k','','single',1:nechoes);
    tic
    % save_nii(make_nii(raw,vox,[0 0 0],32),'img.nii');
    delete k_single_echo_*.raw
    toc
    cd ..
end

% get back to kspace
% raw=ifftshift(raw);
raw = ifft(raw,[],1);
raw = ifft(raw,[],2);
raw = ifft(raw,[],3);
raw=ifftshift(raw);

vox=res; save vox vox; clear res;
%
% WAWRNING: run-rerun variability, a re-loaded mag will be single precision
% but a fresh recon mag will be double! (hopefully that doesn't matter)
%
if ~exist('mag.nii','file')||must_raw
    [raw,phase_shift]=phase_ramp_remove1(raw);
    save phase_shift phase_shift; clear phase_shift;
    raw = iftME(raw);
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
    warning('SKIP SAVINGING mat_format raw becuase its slower than re-calculating!');
    %save raw raw -v7.3
end

%% mask generation
%trying to skip!
%tic
if ~skip_mask
    if ~exist('mag_sos.nii','file')&& ~skip_mask
        % additional step for mag_sos (sum of squares)
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
    if ~exist('msk.nii.gz','file')
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
        display('Threshold Mag SOS in ImageJ then combine with scripted msk')
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
load meanSNR
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
if runno(1) == 'N'
    % agilent 9t
    B0 = 9.4; H = [0 0 1];
elseif runno(1) == 'S'
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
for necho = 1:nechoes
    [back,time] = progress(necho,nechoes,'Phase unwrap and V_SHARP per echo',back,time);
    % if necho <= size(mask,4)
    %     mask2 = applyautocrop(single(mask(:,:,:,necho)));
    % else
    %     mask2 = applyautocrop(mask(:,:,:,1));
    % end
    
    if necho <= size(mask,4)
        mask2 = (single(mask(:,:,:,necho)));
    else
        mask2 = single(mask(:,:,:,1));
    end
    if exist('Freq_v.nii.gz','file') || exist('Freq_v.nii','file')
        continue;
    end
    ScalingCoeff = ScalingFactor(B0,TE_ms(necho));
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
    one_echo=squeeze(raw(:,:,:,necho));
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
    TissuePhase_all(:,:,:,necho) = TissuePhase;
    Freq_v(:,:,:,necho) = (TissuePhase)*ScalingCoeff.Freq;
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

max_echo = 2;
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
% Star QSM

if ~exist('star_qsm.nii.gz','file') && ~exist('star_qsm.nii','file')
    %QSM_star = QSM_STI_Star(FreqC_v,single(mask2),9.4,[0 0 1],[1 1 1],[12 12 12],10,0.6);
    FreqC_v_sc = FreqC_v/ (1./mean(TE_ms(1:max_echo))./2./pi)*2*pi/1000;
    star_qsm = QSM_star(FreqC_v_sc ,single(mask2),'H',H, 'voxelsize',vox,'padsize', prepadsize,'TE',mean(TE_ms(1:max_echo)),'B0',B0,'tau',0.000001);
    %star_qsm = star_qsm*2*pi/1000;
    mat2nii(star_qsm)
end

close all;

