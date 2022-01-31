runs=strsplit('S69228 S69230 S69226 S69222 S69234 S69238 S69244 S69246 S69248 S69242 S69224 S69236 S69232 S69240');
% reducing to just the das qsm which had light sheet.
% specimen, 201907- ( 9  7  3  2 ) :1
% THESE ARE DIFFUSION RUNNOS you dope!
%runs=strsplit('S69237 S69233 S69225 S69223');
% Here are the relevant MGRE scans
runs=strsplit('S69238 S69234 S69226 S69224');


st_dir=pwd;
addpath(genpath('/home/nw61/MATLAB_scripts_rmd'));
code_dir_QSM_STI_star=fullfile(getenv('WKS_HOME'),'recon','CS_v2','QSM','QSM_STI_star');
addpath(genpath(code_dir_QSM_STI_star));
for r=1:numel(runs)
    prototype_qsm_cs_workdir(runs{r});
    cd(st_dir);
end
