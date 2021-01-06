function extract_imagespace_from_CS_tmp(mat_file)
% uses hidden feature of volume_cleanup to save real+imaginary data
% Requires keep_work to have been on for recon.
% Despite the name, requires cs recon setup file as input, NOT the tmp file
%
% Very much a WIP idea/funtion
% 
% initally prototyped as prepare_qsm
% 
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
mat=matfile(mat_file,'Writable',true);
if ~mat.keep_work
  error('keep_work needed to be on for this to work, sorry, you''ll probably need to recon_again.');
end
% Comically poorly named write_qsm option internal to volume_cleanup
% what is REALLY does is write the real, imag component images to
% volumedir/qsm/volume_raw_qsm.mat
mat.write_qsm=1;
try
  volume_cleanup_for_CSrecon_exec(mat_file);
catch merr
  warning(merr.message);
end
