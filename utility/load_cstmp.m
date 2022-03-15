function res=load_cstmp(temp_file,recon_dims,slice_index)
%  res=load_cstmp(temp_file,recon_dims,slice_index)
% loads cs temp file into memory
%  
%  maybe we should infer dims? this *Could figure everything out from the 
% header and assume square dim 2/3
% 
% 
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

% could in the future make temp_file a file handle or a file. not sure if
% thats a good thing or not.
header_size = 1+recon_dims(1);
header_bytes=2*header_size;
%{
[tmp_hdr,~,~,t_id]=load_cstmp_hdr(temp_file);
header_bytes=numel(tmp_hdr)*2+1;
if ~exist('recon_dims','var')
info=dir(temp_file);
data_bytes=info.bytes-header_bytes;
sq_sz=sqrt(data_bytes/2)
recon_dims=[numel(tmp_hdr),sq_sz,sq_sz];
end
%}
s_vector_length = recon_dims(2)*recon_dims(3);
data_offset= header_bytes + (2*8*s_vector_length*(slice_index-1)); % Each slice is double dim_y*dim_z real, then double dim_y*dim_z imaginary

t_id=fopen(temp_file,'r+');
fseek(t_id,data_offset,-1);
reconned_slice=fread(t_id,2*s_vector_length,'double');
fclose(t_id);

res=complex(reconned_slice(1:s_vector_length),reconned_slice((s_vector_length+1):end));
res=reshape(res,[recon_dims(2) recon_dims(3)]);
end