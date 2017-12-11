% Paths to add to cs_recon execs prior to compiling. 
addpath([getenv('WORKSTATION_HOME') '/recon/WavelabMex']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/simulation']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/threshold']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/sparseMRI_v0.2/utils']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/testing_and_prototyping']);
addpath([getenv('WORKSTATION_HOME') '/recon/CS_v2/CS_utilities']);
% common_utils had to be added for cs_recon main
addpath([getenv('WORKSTATION_HOME') '/shared/civm_matlab_common_utils']);
% had to add fermi filter dir to get cleanup to work
addpath([getenv('WORKSTATION_HOME') '/recon/mat_recon_pipe/filter/fermi/']);
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
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/resize/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/slurm/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/wildcardsearch/']);
addpath([getenv('WORKSTATION_HOME') '/shared/mathworks/zips/']);
% 