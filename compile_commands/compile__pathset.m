% Paths to add to cs_recon execs prior to compiling. 
[pdir]=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(pdir,''));
addpath(fullfile(pdir,'sparseMRI_v0.2'));
addpath(fullfile(pdir,'sparseMRI_v0.2/simulation'));
addpath(fullfile(pdir,'sparseMRI_v0.2/threshold'));
addpath(fullfile(pdir,'sparseMRI_v0.2/utils'));
%addpath(fullfile(pdir,'testing_and_prototyping'));
addpath(fullfile(pdir,'utility'));
% common_utils had to be added for cs_recon main
addpath([getenv('WKS_SHARED') '/civm_matlab_common_utils']);
% had to add fermi filter dir to get cleanup to work
addpath([getenv('WORKSTATION_CODE') '/recon/mat_recon_pipe/filter/fermi/']);
addpath([getenv('WORKSTATION_CODE') '/recon/External/WavelabMex']);
% on finding dirrec was required, added remainder of shared/mathworks
% pieces.
addpath([getenv('WKS_SHARED') '/mathworks/align_figure/']);
addpath([getenv('WKS_SHARED') '/mathworks/CompressionLib/']);
addpath([getenv('WKS_SHARED') '/mathworks/dirrec/']);
addpath([getenv('WKS_SHARED') '/mathworks/dlmcell/']);
addpath([getenv('WKS_SHARED') '/mathworks/extrema/']);
addpath([getenv('WKS_SHARED') '/mathworks/hist2/']);
addpath([getenv('WKS_SHARED') '/mathworks/multiecho_enhance/']);
addpath([getenv('WKS_SHARED') '/mathworks/NIFTI_20140122/']);
addpath([getenv('WKS_SHARED') '/mathworks/nrrdWriter/']);
addpath([getenv('WKS_SHARED') '/mathworks/nrrdread/']);
addpath([getenv('WKS_SHARED') '/mathworks/resize/']);
addpath([getenv('WKS_SHARED') '/mathworks/slurm/']);
addpath([getenv('WKS_SHARED') '/mathworks/wildcardsearch/']);
% 
