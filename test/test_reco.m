% a helper to run simple ft on mrsolutions data
% can use compressed sensing or not
%% set files
cs_table='c:/workstation/data/petableCS_stream/other/stream_CS256_16x_pa18_pb73';
mrd_file='c:/smis/dev/Temp/se_test_const_phase.mrd';
output='uint16';

% test mge
% mrd_file='d:/workstation/scratch/c/smis/dev/Temp/Temp.MRD'

% /d/workstation/scratch/dev/MRD/4
% 79 - 88
% 80,81 are big and failed
% non-compressed
% mrd_file='d:/workstation/scratch/dev/MRD/4/';
% "failed" scans, actually it is their recon which fails
mrd_file=fullfile('d:','smis','dev','MRD','4','110',"110_000_0.mrd"); 
mrd_file=fullfile('d:','smis','dev','MRD','4','109',"109_000_0.mrd"); 
mrd_file=fullfile('d:','smis','dev','MRD','4','108',"108_000_0.mrd"); 
mrd_file=fullfile('d:','smis','dev','MRD','4','107',"107_000_0.mrd"); 

% mrd_file='c:/smis/dev/Temp/Temp.MRD'
% mrd_file='c:/smis/dev/Temp/scout.MRD'

% one echo te15 gre test to mach N57710
% sur load snr ~28
% mrd_file=fullfile('d:','smis','dev','MRD','9','180','180_000_0.mrd');

use_fermi_filter=0;

%% resistor test data 
%{
% make sure to to not scale output
output='default';
% hot
mrd_file=fullfile('d:','smis','dev','MRD','9','213','213_000_0.mrd');
% cold
%mrd_file=fullfile('d:','smis','dev','MRD','9','214','214_000_0.mrd');
%}
%% run startup
f_path=which('load_mrd');
if isempty(f_path)
    current_dir=pwd;
    cd c:/workstation/code/shared/pipeline_utilities
    startup
    cd(current_dir);
    clear current_dir;
    f_path=which('load_mrd');
end
addpath(fullfile(fileparts(f_path),'test'));
clear f_path;
%% fix different paths between sys and testbed
assert(exist('mrd_file','var'),'please define mrd_file');
if ~exist('cs_table','var')
    cs_table='';
end
[~,mrd_name]=fileparts(mrd_file);
mrd_file=test_path_flipper_data(mrd_file);
cs_table=test_path_flipper_cs_table(cs_table);
%% get number from test files
mrd_number=0;
reg_res=regexp(mrd_name,'[^0-9]*([0-9]+)$','tokens');
if numel(reg_res) >= 1
    reg_res=reg_res{1};
    mrd_number=str2double(reg_res{1});
    assert(~isnan(mrd_number),'mrd number fail');
end
clear reg_res;
[image_data,mrd_header,kspace_data,mrd_data]=recon_quick(mrd_file,cs_table);
%% save a nifti someplace
if strcmp(output,'uint16')
    save_nii(make_nii(uint16(image_data)),fullfile(pwd(),sprintf('%s.nii',mrd_name)));
else
    save_nii(make_nii(image_data),fullfile(pwd(),sprintf('%s.nii',mrd_name)));
end
