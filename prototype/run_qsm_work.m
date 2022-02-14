
%% 21.das.01 test run
%{
runs={'S69222'}; % diffusion N58204
t_start=tic;
prototype_qsm_group(runs);
t_elapsed=toc(t_start)
return;
%}
%% 19.gaj.43
runs={'N58207'}; % diffusion N58204
t_start=tic;
prototype_qsm_group(runs);
t_19gaj43=toc(t_start);
fprintf('gaj runs took %g hours\n',t_19gaj43/60/60);

%% das study
return;
runs=strsplit('S69228 S69230 S69226 S69222 S69234 S69238 S69244 S69246 S69248 S69242 S69224 S69236 S69232 S69240');
% reducing to just the das qsm which had light sheet.
% specimen, 201907- ( 9  7  3  2 ) :1
% THESE ARE DIFFUSION RUNNOS you dope!
%runs=strsplit('S69237 S69233 S69225 S69223');
% Here are the relevant MGRE scans
runs=strsplit('S69238 S69234 S69226 S69224');

% this one masked worse than the rest.
runs=strsplit('S69234');
prototype_qsm_group(runs);
