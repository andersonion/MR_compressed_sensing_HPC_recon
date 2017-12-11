function gui_exec_test( scanner,runno,study,agilent_series,target_machine,fermi_filter,CS_recon_params,chunk_size )
%GUI_exec_test Testing to see if our gui interface is compatible with a
%matlab exec function...copied from CS_recon_on_cluster code.
%   

if ~exist('target_machine','var')
    target_machine = 'delos';
end

if ~exist('fermi_filter','var')
    fermi_filter=0;
end


if ~exist('chunk_size','var')
    chunk_size=6; % 25 November 2016, temporarily (?) changed to 6
end

if ~exist('CS_recon_params','var')
    CS_recon_params=''; % Added 23 December 2016 or otherwise default values won't work. --BJA
end


%%  cd /cm/shared/workstation_code_dev/shared/pipeline_utilities
%addpath(genpath('/home/rmd22/Documents/MATLAB/'));

%% Get all necessary code for reconstruction
% addpath('/cm/shared/workstation_code/shared/mathworks/slurm_shared');
% addpath('/cm/shared/workstation_code/shared/civm_matlab_common_utils');
% addpath('/cm/shared/workstation_code/shared/mathworks/dirrec');
% addpath('/cm/shared/workstation_code/recon/mat_recon_pipe/mat_wrappers');
% addpath('/cm/shared/workstation_code/shared/mathworks/dlmcell');
% addpath('/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/');
% addpath('/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/sparseMRI_v0.2');
% addpath('/home/rmd22/Documents/MATLAB/MATLAB_scripts_rmd/CS/Wavelab850');

%% Input checks
%Changed recon_path from input variable to hardcoded default for this code...will only need to change if there is amajor change to cluster configuration
%if ~exist('recon_path','var');
recon_path = fullfile('/glusterspace',runno);
%end

if ~exist(recon_path,'dir');
    mkdir(recon_path);
end

% recon_path = [recon_path '/']; %this may not be necessary, just in case
if ~ischar(agilent_series)
    agilent_series = num2str(agilent_series);
    if length(agilent_series) < 2
        agilent_series = ['0' agilent_series];
    end
    agilent_series = ['ser' agilent_series];
end


%% Populate DTI series general header information
databuffer.engine_constants = load_engine_dependency();
databuffer.scanner_constants = load_scanner_dependency(scanner);
databuffer.headfile.U_runno = runno;
databuffer.headfile.U_scanner = scanner;
databuffer.input_headfile = struct;
optstruct.testmode = false;
optstruct.debug_mode = 0;
optstruct.warning_pause = 0;
optstruct.param_file = boolean(0);% [runno '.param'];
gui_info_collect(databuffer,optstruct);

%% Pull fid and procpar, load reconstruction parameter data
% CSreconfile = agilent2glusterspaceCS_wn(scanner,runno,study,series,recon_path);
reconfile = agilent2glusterspaceCS(scanner,runno,study,agilent_series,recon_path);

load(reconfile)
%% Pull CS table (bypass reading it from procpar directly)
full_CS_table_path = procpar.petableCS;
CS_table_parts = strsplit(full_CS_table_path{1},'/');
CS_table_name = CS_table_parts{end};

%target_folder = [fileparts(procparpath) '/'];
table_target = [recon_path '/' CS_table_name];

pull_table_cmd = ['puller_simple  -o -f file ' scanner ' ''../../../../home/vnmr1/vnmrsys/tablib/' CS_table_name ''' ' recon_path];
if ~exist(table_target,'file')
    system(pull_table_cmd)
end

end

