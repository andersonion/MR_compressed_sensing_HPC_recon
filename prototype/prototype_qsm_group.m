function prototype_qsm_group(runs)
if ~iscell(runs)
    runs=strsplit(runs);
end
st_dir=pwd;
addpath(genpath('/home/nw61/MATLAB_scripts_rmd'));
code_dir_QSM_STI_star=fullfile(getenv('WKS_HOME'),'recon','CS_v2','QSM','QSM_STI_star');
addpath(genpath(code_dir_QSM_STI_star));
for r=1:numel(runs)
    prototype_qsm_cs_workdir(runs{r});
    cd(st_dir);
end
return;
end