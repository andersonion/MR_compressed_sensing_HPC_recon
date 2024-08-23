function prototype_qsm_path()
%% add ALTERNATE code versions from russ-bucket
% WARNING WARNING WARNING! ORDER OF ADDITION IS CRITICAL! SEVERAL FUNCTIONS
% OVERRIDE ONE ANOTHER AND ARE DIFFERENT!(in subtle dumb ways!)
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','agilent'));
%% add other russ code
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','ImageProcessing'));
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','AgilentReconScripts'));
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','NIFTI_20130306_with_edits'));
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','MTools'));
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','MultipleEchoRecon'));
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','MATLAB_scripts_rmd','Segmentation'));
addpath(fullfile(getenv('WORKSTATION_CODE'),'recon','External','XCalc'));
%%% THIS MUST BE LAST OR THINGS BREAK!
code_dir_QSM_STI_star=fullfile(getenv('WORKSTATION_CODE'),'recon','External','QSM_STI_star');
addpath(genpath(code_dir_QSM_STI_star));
return;
end
