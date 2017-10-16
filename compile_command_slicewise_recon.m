%compile me
script_name = 'slicewise_CSrecon';


matlab_path = '/cm/shared/apps/MATLAB/R2015b/';
master_dir = '/cm/shared/workstation_code_dev/matlab_execs/';
main_dir = [master_dir script_name '_executable/'];
%main_dir = '/nas4/rja20/CS_recon_setup_executable/'


ts=fix(clock);
compile_time=sprintf('%04i%02i%02i_%02i%02i%02i',ts(1:5));

my_dir = [main_dir compile_time '/']
% % Find next empty directory
% valid_letters = ['ABCDEFGHJKLMNPQRSTUVWXYZ'];
% available_dir_found=0;
% 
% for L1 = 1:length(valid_letters)
%     for L2 = 1:length(valid_letters)
%         if ~available_dir_found
%            my_dir = [main_dir valid_letters(L1) valid_letters(L2)];
%            if ~exist(my_dir,'dir')
%               available_dir_found = 1; 
%            end     
%         end
%     end
% end

%my_dir =  '/glusterspace/BJ/EK'
addpath('/cm/shared/workstation_code_dev/recon/CS_v2/');

version = 1;

if (version == 1)
    v_string = '';
elseif (version > 1)
    v_string = ['_V' num2str(version)];
end

mkdir(my_dir)
eval(['!chmod a+rwx ' my_dir])

%source_dir =  '/cm/shared/workstation_code_dev/recon/CS/';
%source_dir='/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/';
source_dir='/cm/shared/workstation_code_dev/recon/CS_v2/';
source_filename = ['slicewise_CSrecon_exec' v_string '.m'];
source_file = [source_dir source_filename]

include_string =[];
%{
include_files = {'/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/sparseMRI_v0.2/@Wavelet/Wavelet.m'...
   '/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/sparseMRI_v0.2/fnlCg.m'...
   '/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850/Orthogonal/'...
   '/cm/shared/apps/MATLAB/R2015b/toolbox/stats/stats/quantile.m'...
   '/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850/reverse.m'};
%}
%'/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850/Orthogonal/'...

include_files = {'/cm/shared/apps/MATLAB/R2015b/toolbox/stats/stats/quantile.m'};


for ff = 1:length(include_files)
    include_string = [include_string ' -a ' include_files{ff} ' '];
    %system(cp_cmd);
end

eval(['mcc -N -d  ' my_dir...
   ' -C -m '...
   ' -R -singleCompThread -R nodisplay -R nosplash -R nojvm '...
   ' ' include_string ' '...
   ' ' source_file ';']) 
   %' -a /home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850/WavePath2.m '...
   %' /home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/CS_recon_cluster_setup_work_exec.m;'])


cp_cmd_2 = ['cp  ' source_file ' ' my_dir];
system(cp_cmd_2)
for ff = 1:length(include_files)
    cp_cmd = ['cp ' include_files{ff} ' ' my_dir];
    system(cp_cmd);
end
%
%    -a /cm/shared/workstation_code_dev/recon/mat_recon_pipe/filter/fermi/fermi_filter_isodim2_memfix.m ...
first_run_cmd = [my_dir '/run_' source_filename];
first_run_cmd(end)=[];
first_run_cmd = [first_run_cmd 'sh ' matlab_path];
system(first_run_cmd);
eval(['!chmod a+rwx -R ' my_dir '/*'])