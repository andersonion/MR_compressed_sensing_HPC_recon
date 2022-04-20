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

mrd_file='c:/smis/dev/Temp/scout.MRD'
mrd_file='c:/smis/dev/Temp/Temp.MRD'

% CSFID grants garbage
% mrd_file=fullfile('d:','smis','dev','MRD','9','188','188_000_0.mrd'); 
% mrd_file=fullfile('d:','smis','dev','MRD','9','189','189_000_0.mrd'); 

% mrd_file="C:\smis\dev\Temp\test_scout.MRD"
% fov ratio 2, this looks normal, but doesnt fill the view well
mrd_file=fullfile('d:','smis','dev','MRD','9','206','206_000_0.mrd');
% fov ratio 1, this looks squashed!
mrd_file=fullfile('d:','smis','dev','MRD','9','207','207_000_0.mrd'); 
mrd_file='c:/smis/dev/Temp/Temp.MRD'
mrd_file='c:/smis/dev/Temp/init_gre2_nongated_long.mrd';

mrd_file=fullfile('d:','smis','dev','MRD','9','216','216_000_0.mrd');

% "quick" fse tests, using echo time of 9-12, increasing bandwidth if
% needed, keeping tr ~22
% fse test 200um
% fov-ratio wrong, was left at 1
% mrd_file=fullfile('d:','smis','dev','MRD','9','219','219_000_0.mrd');
mrd_file=fullfile('d:','smis','dev','MRD','9','222','222_000_0.mrd');
% fse test 100um
% fov-ratio wrong, was left at 1
% mrd_file=fullfile('d:','smis','dev','MRD','9','220','220_000_0.mrd');
%mrd_file=fullfile('d:','smis','dev','MRD','9','223','223_000_0.mrd');
% fse test  50um
%mrd_file=fullfile('d:','smis','dev','MRD','9','224','224_000_0.mrd');
% reduce bandwidth from 100KHz and adjust te/tr accordingly
%mrd_file=fullfile('d:','smis','dev','MRD','9','225','225_000_0.mrd');
mrd_file='c:/smis/dev/Temp/Temp.MRD'

%% resistor test data 
%{
% make sure to to not scale output
output='default';
% hot
mrd_file=fullfile('d:','smis','dev','MRD','9','213','213_000_0.mrd');
% cold
mrd_file=fullfile('d:','smis','dev','MRD','9','214','214_000_0.mrd');
%}
%% run startup
f_path=which('load_mrd');
if isempty(f_path)
    current_dir=pwd;
    cd c:/workstation/code/shared/pipeline_utilities
    startup
    cd(current_dir);
end
clear f_path;
%% fix different paths between sys and testbed
[~,mrd_name]=fileparts(mrd_file);
% this only works if original was scanner path.
assert(exist('mrd_file','var'),'please define mrd_file');
if ~exist('cs_table','var')
    cs_table='';
end
smis_dir='d:/workstation/scratch/c/smis';
if ~exist(cs_table,'file')
    cs_table=regexprep(cs_table,'^c','d');
end
if ~exist(mrd_file,'file')
    mrd_file=regexprep(mrd_file,'^c:/smis',smis_dir);
end
clear smis_dir;
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