function bulk_extract_imagespace_from_CS_tmp(WORKFOLDER)
% uses hidden feature of volume_cleanup to save real+imaginary data
% Very much a WIP idea/funtion
% 
% initally prototyped as prepare_qsm
% 
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
mat_files=wildcardsearch(WORKFOLDER,'*setup_variables.mat')
for file_n=1:numel(mat_files)
     extract_imagespace_from_CS_tmp(mat_files{file_n});
end

