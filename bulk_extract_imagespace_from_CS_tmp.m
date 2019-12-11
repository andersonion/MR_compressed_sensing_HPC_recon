function bulk_extract_imagespace_from_CS_tmp(WORKFOLDER)
% uses hidden feature of volume_cleanup to save real+imaginary data
% Very much a WIP idea/funtion
% 
% initally prototyped as prepare_qsm
% 
mat_files=wildcardsearch(WORKFOLDER,'*setup_variables.mat')
for file_n=1:numel(mat_files)
     extract_imagespace_from_CS_tmp(mat_files{file_n});
end

