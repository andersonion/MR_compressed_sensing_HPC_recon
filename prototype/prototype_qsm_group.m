function prototype_qsm_group(runs)
if ~iscell(runs)
    runs=strsplit(runs);
end
st_dir=pwd;


%% add ALTERNATE code versions from russ-bucket
% WARNING WARNING WARNING! ORDER OF ADDITION IS CRITICAL! SEVERAL FUNCTIONS
% OVERRIDE ONE ANOTHER AND ARE DIFFERENT!(in subtle dumb ways!)
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','agilent'));
%% add other russ code
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','ImageProcessing'));
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','AgilentReconScripts'));
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','NIFTI_20130306_with_edits'));
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','MTools'));
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','MultipleEchoRecon'));
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','Segmentation'));
addpath(fullfile(getenv('WKS_HOME'),'recon','XCalc'));
%{
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','
addpath(fullfile(getenv('WKS_HOME'),'recon','MATLAB_scripts_rmd','
%}
%%% THIS MUST BE LAST OR THINGS BREAK!
code_dir_QSM_STI_star=fullfile(getenv('WKS_HOME'),'recon','QSM_STI_star');
addpath(genpath(code_dir_QSM_STI_star));

%% do work for each
for r=1:numel(runs)
    prototype_qsm_cs_workdir(runs{r});
    cd(st_dir);
end

return;
end
