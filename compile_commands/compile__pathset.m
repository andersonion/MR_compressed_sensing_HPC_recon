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
addpath([getenv('WORKSTATION_HOME') '/shared/civm_matlab_common_utils']);
addpath([getenv('WORKSTATION_HOME') '/shared/civm_matlab_common_utils/mrsolutions']);
addpath([getenv('WORKSTATION_HOME') '/shared/civm_matlab_common_utils/agilent']);
% addpath([getenv('WORKSTATION_HOME') '/shared/civm_matlab_common_utils/classy']);
% had to add fermi filter dir to get cleanup to work
addpath([getenv('WORKSTATION_HOME') '/recon/mat_recon_pipe/filter/fermi/']);
addpath([getenv('WORKSTATION_HOME') '/recon/WavelabMex']);
% on finding dirrec was required, added remainder of shared/mathworks
% pieces.
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/align_figure/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/CompressionLib/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/dirrec/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/dlmcell/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/extrema/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/hist2/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/multiecho_enhance/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/NIFTI_20140122/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/nrrdWriter/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/nrrdread/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/resize/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/slurm/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/wildcardsearch/']);
% 
