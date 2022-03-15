function res=CS_tmp_load(temp_file,recon_dims,slice_index)
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

% could in the future make temp_file a file ident or a file. not sure if
% thats a good thing or not.
header_size = 1+recon_dims(1);
s_vector_length = recon_dims(2)*recon_dims(3);
data_offset= 2*header_size + (2*8*s_vector_length*(slice_index-1)); % Each slice is double dim_y*dim_z real, then double dim_y*dim_z imaginary

t_id=fopen(temp_file,'r+');
fseek(t_id,data_offset,-1);
reconned_slice=fread(t_id,2*s_vector_length,'double');
fclose(t_id);

res=complex(reconned_slice(1:s_vector_length),reconned_slice((s_vector_length+1):end));
res=reshape(res,[recon_dims(2) recon_dims(3)]);
end
