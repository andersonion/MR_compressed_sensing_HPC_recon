%% pull the data and create raw image
% addpath('/glusterspace/AgilentReconScripts')
% addpath('/home/nian/MATLAB_scripts_rmd/AgilentReconScripts')
% addpath('/home/nian/MATLAB_scripts_rmd/MTools')
% addpath('/home/nian/MATLAB_scripts_rmd/AgilentReconScripts')
% addpath('/home/nian/MATLAB_scripts_rmd/MultipleEchoRecon')
% addpath('/home/nw61/MATLAB_scripts_rmd')
addpath(genpath('/home/nw61/MATLAB_scripts_rmd'));


% rad_mat('heike','N56315','N56275_02/ser53.fid');  %%%%DTI NO fermi filter

% scanner = 'kamy';
% runno = 'S66730';
% study = 'S66730_01';a
% series = 'ser13';
% rad_mat('heike','N56302','N56275_02/ser12.fid',{'skip_filter'});  %%%%GRE
scanner = 'kamy';
runno = 'S69054s';
study = 'S200221_05';
series = 'ser49';

%workpath = agilent2glusterspace_k(scanner,runno,study,series,'o');
workpath = agilent2nas4_k(scanner,runno,study,series);
cd(workpath);



%
load([runno 'recon.mat']);
mkdir ser12
cd ser12
save fov fov
vox = res; save vox vox
TE = procpar.TE/1000; save TE TE
dims = [voldims nechoes]; save dims dims

% phase ramp removal
load_fid_ME_wrapper4;
raw = iftME(phase_ramp_remove1(readMEraw('k','','single',1:nechoes)));
[raw,shift_vector] = autoC(raw); save shift_vector shift_vector;
%show3(abs(raw(:,:,:,1)));
img=single(raw);

%
tic
% save_nii(make_nii(raw,vox,[0 0 0],32),'img.nii');
delete k_single_echo_*.raw
toc
cd ..
%%
% additional step for mag_sos
mag_sos = zeros(size(raw(:,:,:,1)));
for echo_num = 1:size(raw,4)
    mag_sos = (abs(raw(:,:,:,echo_num))).^2 + mag_sos;
end

mag_sos = sqrt(mag_sos);
mat2nii(mag_sos);

% show3(mag_sos);

mag=abs(img);
mat2nii(mag)
[T2,R2]=T2mapMaskedWeighted(abs(img),TE*1000);
mat2nii(T2)
mat2nii(R2)
save img img -v7.3



%tic
[~] = brainext(abs(mag_sos),3,0.45);
%[~] = brainext(abs(mag_sos),2,0.65);

display('Threshold Mag SOS in ImageJ then combine with scripted msk')
%%


msk = open_nii('msk.nii.gz');
msk_thresh = open_nii('msk_thresh.nii');
msk_comb = msk.*msk_thresh;
mat2nii(msk_comb)


%% QSM Recon Pipe
 
% Determine SNR and calculate T2 map
img = raw;
img = abs(img);
mask = load_nii('msk_comb.nii.gz'); mask = single(mask.img);

autoSNR(abs(img),mask);
load meanSNR
load('TE.mat') % array with echo times such as TE = [0.04 0.08 ...]
load('vox.mat') % array with voxel size in each dimension such as vox = [0.1 0.1 0.1]

T2 = T2mapMaskedWeighted(img(:,:,:,1:4),TE(1:4),mask,meanSNR(1:4));
save_nii(make_nii(T2),'T2.nii');

% QSM

clear all;

% prep
prepad = 1;
%nprepad = 16;
nprepad = 12;
prepadsize = [nprepad nprepad nprepad]; % performed by Wei's scripts
padsize = 2; %boundary left by autocrop for speed
% phi = angle(open_nii('img.nii'));
tic
load dims % array with dimensions of raw img ex. dims = [256 256 256 4]
load TE
raw_img_file = 'img.nii';
mask = open_nii('msk_comb.nii.gz');
mask = imdilate(mask,strel3d(2));
mask = imerode(mask,strel3d(2)); 
save_nii(make_nii(mask,[1 1 1],[0 0 0],2),'maskE.nii');

%autocrop(mask,padsize);
toc

% Calculate unwrapped and filtered phase

%B0 = 3.0; H = [1 0 0]; % define B0 and direction of main field H
B0 = 9.4; H = [0 0 1];
%B0 = 7.0; H = [0 0 1];
niter = 50;


idx = 1:dims(4)
%idx = 1:2
combinedX_flag = 1;
X_flag = 1;

% Freq = zeros([dims(1:3) 8],'single');
% manually set num echos to use: 3
Freq = zeros([dims],'single');

if TE(1) < 1
    TE = TE*1e3; % s -> ms
end
for necho = idx;
    necho
ScalingCoeff = ScalingFactor(B0,TE(necho));

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

%TissuePhase = iHARPERELLA(applyautocrop(single(angle( ...
                          %open_nii(raw_img_file,necho)))),mask2,'padsize',prepadsize);
                      
UnwrapPhase = LaplacianPhaseUnwrap((single(angle( ...
                          open_nii(raw_img_file,necho)))),'padsize',prepadsize);
                      
TissuePhase = V_SHARP(UnwrapPhase,single(mask2),'padsize',prepadsize);
TissuePhase_all(:,:,:,necho) = TissuePhase;  

Freq_v(:,:,:,necho) = (TissuePhase)*ScalingCoeff.Freq;
%figure;imshow(Freq_v(:,:,160,necho),[])
%drawnow;
end

mat2nii(Freq_v);
% mat2nii(UnwrapPhase)
mat2nii(TissuePhase_all)


% Combine echoes to enhance images and save results in Nifti format.

% statmask = HeartT2Mask('mag.nii',1,2);
% mat2nii(statmask);

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
clear T2 T2pix TissuePhase maskE2 raw T2mask

max_echo = 2;
% meanT2 = open_nii('T2.nii');
% combine frequency data
[~,FreqC_v] = nanMEW(TE(1:max_echo)/1e3,meanT2,Freq_v(:,:,:,1:max_echo));
mat2nii(FreqC_v);
save MEWeight meanT2

%clear Freq

% Star QSM
 %QSM_star = QSM_STI_Star(FreqC_v,single(mask2),9.4,[0 0 1],[1 1 1],[12 12 12],10,0.6);
 load vox
 FreqC_v_sc = FreqC_v/ (1./mean(TE(1:max_echo))./2./pi)*2*pi/1e3;
 star_qsm = QSM_star(FreqC_v_sc ,single(mask2),'H',H, 'voxelsize',vox,'padsize', prepadsize,'TE',mean(TE(1:max_echo)),'B0',B0,'tau',0.000001);
 %star_qsm = star_qsm*2*pi/1e3;
 mat2nii(star_qsm)

