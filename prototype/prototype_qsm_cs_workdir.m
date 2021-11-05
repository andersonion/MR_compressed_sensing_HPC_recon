%% pull the data and create raw image
function prototype_qsm_cs_workdir(runno)
% addpath('/glusterspace/AgilentReconScripts')
% addpath('/home/nian/MATLAB_scripts_rmd/AgilentReconScripts')
% addpath('/home/nian/MATLAB_scripts_rmd/MTools')
% addpath('/home/nian/MATLAB_scripts_rmd/AgilentReconScripts')
% addpath('/home/nian/MATLAB_scripts_rmd/MultipleEchoRecon')
% addpath('/home/nw61/MATLAB_scripts_rmd')
addpath(genpath('/home/nw61/MATLAB_scripts_rmd'));
code_dir_QSM_STI_star=fullfile(getenv('WKS_HOME'),'recon','CS_v2','QSM','QSM_STI_star');
addpath(genpath(code_dir_QSM_STI_star));

% rad_mat('heike','N56315','N56275_02/ser53.fid');  %%%%DTI NO fermi filter

% scanner = 'kamy';
% runno = 'S66730';
% study = 'S66730_01';a
% series = 'ser13';
% rad_mat('heike','N56302','N56275_02/ser12.fid',{'skip_filter'});  %%%%GRE
scanner = 'kamy';
%runno = 'S69054s';
study = 'S200221_05';
series = 'ser49';

% reset for new test data where we have fetched from archive.
% To fit the old data setuo to get started, a CS_v2 recon work folder was
% copied from RUNNO.work to RUNNO
% hard links were created from fid to RUNNO.fid
% and procpar to RUNNO.procpar
%runno = 'S69240';
study='localdata';
series='localseries';
use_new_CS=1;
skip_mask=1;

%% old fashioned get data from scanner out of use
if ~use_new_CS
    % workpath returned by agilent2nas4(and similar
    % scripts) it is a old format CS recon folder.
    %workpath = agilent2glusterspace_k(scanner,runno,study,series,'o');
    workpath=fullfile(getenv('BIGGUS_DISKUS'),runno );
    if ~exist(workpath,'dir')
        workpath = agilent2nas4_k(scanner,runno,study,series);
    end
end
% new CS_v2 data format, had to be run with keep_work option to be useful
workpath=fullfile(getenv('BIGGUS_DISKUS'),[runno '.work']);
%workpath='/mnt/duhsnas-pri.dhe.duke.edu/civm-projectdata/jjc29/clusterscratch/S69222.work'
cd(workpath);

if exist('star_qsm.nii.gz','file')
    warning('%s complete',workpath);
    return;
end

%% example to load CS data
if use_new_CS
    raw=load_imagespace_from_CS_tmp(workpath);
    % get back to kspace
   % raw=ifftshift(raw);
    raw = ifft(raw,[],1);
    raw = ifft(raw,[],2);
    raw = ifft(raw,[],3);
    raw=ifftshift(raw);
    %disp_vol_center(raw(:,:,:,1))
    %
    procpar=readprocpar(fullfile(workpath,'procpar'));
    %vars=matfile([runno 'recon.mat']);
    
    voldims=[procpar.np/2 procpar.nv procpar.nv2];
    % not-valid becuse CS
    %nvols=(npoints/2*ntraces*nblocks)/prod(voldims);
    %blocks_per_vol=nblocks/nvols;
    fov=[procpar.lro procpar.lpe procpar.lpe2].*10; %fov in mm this may not be right for multislice data
    res=fov./voldims;
    vox=res; save vox vox; clear res;
    
    if exist('procpar','var')
        nechoes = numel(procpar.TE);
    else
        nechoes = 1;
    end
    TE = procpar.TE/1000; 
    dims = [voldims nechoes];
elseif exists('cartesean_sample_example','var')
    %% this was written for NON-CS data!
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
raw = iftME(phase_ramp_remove1(raw));
[raw,shift_vector] = autoC(raw); save shift_vector shift_vector;
%show3(abs(raw(:,:,:,1)));
img=single(raw);
%
%%
if ~exist('mag.nii','file')
    mag=abs(img);
    mat2nii(mag)
end
if ~exist('R2.nii.gz','file')
    [T2,R2]=T2mapMaskedWeighted(mag,TE*1000);
    mat2nii(T2)
    mat2nii(R2)
end
if ~exist('img.mat','file')
    warning('SKIP SAVINGING IMG becuase its slower than re-calculating!');
    %save img img -v7.3
end

%% mask generation
%trying to skip!
%tic
if ~skip_mask
    if ~exist('mag_sos.nii','file')&& ~skip_mask
        % additional step for mag_sos
        mag_sos = zeros(size(raw(:,:,:,1)));
        for echo_num = 1:size(raw,4)
            mag_sos = (abs(raw(:,:,:,echo_num))).^2 + mag_sos;
        end
        mag_sos = sqrt(mag_sos);
        mat2nii(mag_sos);
        % show3(mag_sos);
    end
    if ~exist('msk.nii.gz','file')
        [~] = brainext(abs(mag_sos),3,0.45);
        %[~] = brainext(abs(mag_sos),2,0.65);
        display('Threshold Mag SOS in ImageJ then combine with scripted msk')
    end
    %%
    if ~exist('msk_comb.nii.gz','file')
        msk = open_nii('msk.nii.gz');
        try
            msk_thresh = open_nii('msk_thresh.nii');
            msk_comb = msk.*msk_thresh;
        catch
            warning('no mask_comb, just using small mask');
            msk_comb=msk;
        end
        mat2nii(msk_comb);
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
img = raw;
if ~exist('mask','var') && ~skip_mask
    mask = load_nii('msk_comb.nii.gz');
    mask = single(mask.img);
end
if ~exist('meanSNR.mat','file')
    if ~exist('mask','var')
        autoSNR(abs(img));
    else
        autoSNR(abs(img),mask);
    end
end
load meanSNR
if skip_mask
    mask=ones(voldims,'single');
end
% these should already be in memory from above.
% load('TE.mat') % array with echo times such as TE = [0.04 0.08 ...]
% load('vox.mat') % array with voxel size in each dimension such as vox = [0.1 0.1 0.1]

% before img had been converted to magnitude
%T2 = T2mapMaskedWeighted(img(:,:,:,1:4),TE(1:4),mask,meanSNR(1:4));
T2 = T2mapMaskedWeighted(abs(img),TE,mask,meanSNR);
save_nii(make_nii(T2),'T2.nii');

% QSM
% clear all;
clear R2 T2 msk msk_comb

%% prep
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
if ~exist('maskE.nii.gz','file') 
    if ~skip_mask
        %mask = open_nii('msk_comb.nii.gz');
        mask = imdilate(mask,strel3d(2));
        mask = imerode(mask,strel3d(2));
        save_nii(make_nii(mask,[1 1 1],[0 0 0],2),'maskE.nii');
    end
else
    mask=open_nii('maskE.nii.gz');
end
%autocrop(mask,padsize);
toc

% Calculate unwrapped and filtered phase

%B0 = 3.0; H = [1 0 0]; % define B0 and direction of main field H
warning('hard coding B0 and H field');
% agilent 9t
B0 = 9.4; H = [0 0 1];
% agilent 7t
B0 = 7.0; H = [0 0 1];
niter = 50;
%%

%idx = 1:dims(4)
%idx = 1:2
combinedX_flag = 1;
X_flag = 1;

% Freq = zeros([dims(1:3) 8],'single');
% manually set num echos to use: 3
Freq = zeros([dims],'single');

if TE(1) < 1
    TE = TE*1e3; % s -> ms
end
for necho = 1:dims(4);
    necho
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
    if exist('Freq_v.nii.gz','file')
        continue;
    end
    ScalingCoeff = ScalingFactor(B0,TE(necho));
    
    %TissuePhase = iHARPERELLA(applyautocrop(single(angle( ...
    %open_nii(raw_img_file,necho)))),mask2,'padsize',prepadsize);
        
    % raw_img_file was NOT present!
    %%one_echo=open_nii(raw_img_file,necho);
    % NOT certain that raw is the same here!
    % however, the output looks correct.
    one_echo=squeeze(raw(:,:,:,necho));
    UnwrapPhase = LaplacianPhaseUnwrap( ...
        (single(angle(one_echo))),'padsize',prepadsize);
    
    TissuePhase = V_SHARP(UnwrapPhase,single(mask2),'padsize',prepadsize);
    TissuePhase_all(:,:,:,necho) = TissuePhase;
    
    Freq_v(:,:,:,necho) = (TissuePhase)*ScalingCoeff.Freq;
    %figure;imshow(Freq_v(:,:,160,necho),[])
    %drawnow;
end
if ~exist('Freq_v.nii.gz','file')
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
    % T2mask = open_nii('statmask.nii');
    % T2mask = open_nii('maskE.nii');
    T2mask = mask;
    T2mask(T2mask ~= 1) = 0;
    % T2file = dir('T2*.nii');
    % T2 = open_nii(T2file.name);
    T2 = open_nii('T2.nii');
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
% meanT2 = open_nii('T2.nii');
% combine frequency data
if ~exist('FreqC_v.nii.gz','file')
    [~,FreqC_v] = nanMEW(TE(1:max_echo)/1e3,meanT2,Freq_v(:,:,:,1:max_echo));
    mat2nii(FreqC_v);
else
    FreqC_v=open_nii('FreqC_v.nii.gz');
end
clear Freq_v
% Star QSM
%QSM_star = QSM_STI_Star(FreqC_v,single(mask2),9.4,[0 0 1],[1 1 1],[12 12 12],10,0.6);
FreqC_v_sc = FreqC_v/ (1./mean(TE(1:max_echo))./2./pi)*2*pi/1e3;
star_qsm = QSM_star(FreqC_v_sc ,single(mask2),'H',H, 'voxelsize',vox,'padsize', prepadsize,'TE',mean(TE(1:max_echo)),'B0',B0,'tau',0.000001);
%star_qsm = star_qsm*2*pi/1e3;
mat2nii(star_qsm)

close all;

