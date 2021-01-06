function complex_vol=load_imagespace_from_CS_tmp(WORKFOLDER)
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

mat_files=wildcardsearch(WORKFOLDER,'*_raw_qsm.mat')
if numel(mat_files)==0
    bulk_extract_imagespace_from_CS_tmp(WORKFOLDER);
    mat_files=wildcardsearch(WORKFOLDER,'*_raw_qsm.mat');
end
mat=matfile(mat_files{1});
volumes=numel(mat_files);
% silly trick to get zeros to make a complex volume
lil_dummy = zeros([1,1],'double'); lil_dummy = complex(lil_dummy,lil_dummy);
complex_vol=zeros([size(mat.real_data),volumes],'like',lil_dummy);

for file_n=1:numel(mat_files)
    load(mat_files{file_n});
    complex_vol(:,:,:,file_n)=complex(real_data,imag_data);
end
