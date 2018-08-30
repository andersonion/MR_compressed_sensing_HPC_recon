function CS_preview_data(original_mask,data,out_base)
original_dims=[size(data,1),size(original_mask)];
lil_dummy = zeros([1,1],'double');
lil_dummy = complex(lil_dummy,lil_dummy);
temp_data=zeros(original_dims,'like',lil_dummy);
% populate full array with all the data.
for n = 1:original_dims(1)
    temp_data(n,original_mask(:))=data(n,:);
end
% save basic kspace preview
disp_vol_center(temp_data,1,301,sprintf('%s_1_kspace_ortho.tif',out_base));
%% get transform of ksapce to see base image.
temp_data=fftshift(fftshift(ifft(ifft(fftshift(fftshift(temp_data,2),3),[],2),[],3),2),3);
disp_vol_center(abs(temp_data),0,302,sprintf('%s_2_imgspace_ortho.png',out_base));
%% invert transform again to see fully populated kspace
temp_data=fftshift(ifftn(fftshift(temp_data)));
%{
temp_data=fftshift(fftshift(fftshift(...
    ifft(ifft(ifft(...
    fftshift(fftshift(fftshift(temp_data,1),2),3)...
    ,[],1),[],2),[],3)...
    ,1),2),3);
%}
disp_vol_center(temp_data,1,303,sprintf('%s_3_kspace_inv_ortho.tif',out_base));
end