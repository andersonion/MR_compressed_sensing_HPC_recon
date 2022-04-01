% a helper to run simple ft on mrsolutions data
% can use compressed sensing or not
%% run startup
f_path=which('load_mrd');
if isempty(f_path)
    current_dir=pwd;
    cd c:/workstation/code/shared/pipeline_utilities
    startup
    cd(current_dir);
end
clear f_path;
%% set files
%cs_table='c:/workstation/data/petableCS_stream/stream_CS256_8x_pa18_pb54';
%mrd_file='c:/smis/dev/Temp/se_test.mrd';

%cs_table='c:/workstation/data/petableCS_stream/stream_CS256_8x_pa18_pb54';
%mrd_file='c:/smis/dev/Temp/se_test_1.mrd';
%mrd_file='c:/smis/dev/Temp/se_test_2.mrd';
%mrd_file='c:/smis/dev/Temp/se_test_3.mrd';
% test 4 requires editing the CS_table removing the final point, 
% solved automatically by stealing the number out
cs_table='c:/workstation/data/petableCS_stream/other/stream_CS256_16x_pa18_pb73';
%mrd_file='c:/smis/dev/Temp/se_test_4.mrd';
%mrd_file='c:/smis/dev/Temp/se_test_5.mrd';
%mrd_file='c:/smis/dev/Temp/se_test_6.mrd';

% starting with test 10 we had some diffusion gradients on
mrd_file='c:/smis/dev/Temp/se_test_10.mrd';
% broken mrd_file='c:/smis/dev/Temp/se_test_11.mrd';
mrd_file='c:/smis/dev/Temp/se_test_12.mrd';
mrd_file='c:/smis/dev/Temp/se_test_13.mrd';
%mrd_file='c:/smis/dev/Temp/se_test_14.mrd';
mrd_file='c:/smis/dev/Temp/se_test_15.mrd';
mrd_file='c:/smis/dev/Temp/se_test_const_phase.mrd';

[~,mrd_name]=fileparts(mrd_file);
%% fix different paths between sys and testbed
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
%% load data and mask
[mrd_header,mrd_data]=load_mrd(mrd_file,'double');
volume_dims=size(mrd_data);volume_dims(volume_dims==1)=[];
if nnz(volume_dims)==2 
    % exist(cs_table,'file') 
    % [mask_size,pa,pb,cs_factor]=cs_table_name_decode(cs_table);
    idx_mask=load_cs_table(cs_table);
    % patch one data_file generated wrongly(really its the mask's fault having
    % 1 bonus point)
    if mrd_number==4;  idx_mask(end)=0;  end
    volume_dims=[mrd_header.Dimension(1),size(idx_mask)];
end
%{
% load ruslan and convert to expected order
% if centering use cen string
[rim,dim,ppr]=Get_mrd_3D5(mrd_file,'not','not');
% simple 3d only, put data into simple order, readout, views, views2
% this should be the "correct" thing to do, however it gives bad output
t_data=permute(rim,[3,1,2]);
% this undoes the internal fun of Get_mrd_3D5, we'll not use it for now.
%%t_data=permute(rim,[3,2,1]);
mrd_data=t_data; clear t_data rim;
mrd_number=mrd_number+1000;
%}
%% insert mrd data into fully sampled space, and show kspace
if exist(cs_table,'file')
    lil_dummy=complex(0,0);
    kspace_data=zeros(volume_dims,'like',lil_dummy);
    if ndims(mrd_data) > 2
        % reshape if not simple ordering
        mrd_data=reshape(mrd_data,[volume_dims(1),numel(mrd_data)/volume_dims(1)]);
    end
    kspace_data(:,idx_mask(:)==1)=mrd_data;
    kspace_data=reshape(kspace_data,volume_dims);
else
    kspace_data=mrd_data;
end
% display fully sampled kspace
disp_vol_center(kspace_data,1,200+mrd_number)
%% get images space and display
% quick dirty guess
% image_data=fftshift(fftn(fftshift(kspace_data)));
% "correct" from rad_mat(for 3d)
image_data=fftshift(fftshift(fftshift(...
    ifft(ifft(ifft(...
    fftshift(fftshift(fftshift(kspace_data,1),2),3)...
    ,[],1),[],2),[],3)...
    ,1),2),3);
% magnitude and truncate max removing bright artifacts.
image_data=abs(image_data);
s_dat=sort(image_data(:));
max=s_dat(round(numel(s_dat)*0.9995));
image_data(image_data>=max)=max;
% scale max to uint16
image_data=image_data/max*(2^16-1);
disp_vol_center(image_data,1,230+mrd_number);
%% save a nifti someplace
save_nii(make_nii(uint16(image_data)),fullfile(pwd(),sprintf('%s.nii',mrd_name)));