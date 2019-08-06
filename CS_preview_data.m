function img=CS_preview_data(original_mask,data,out_base,mode)
% mode, slice or volume
mtxt='';
if isempty(regexpi(mode,'volume','ONCE'))
    %mode text
    mtxt='_ortho';
end
img{1}=sprintf('%s_1_kspace%s.nii',out_base,mtxt);
img{2}=sprintf('%s_2_imgspace%s.nii',out_base,mtxt);
img{3}=sprintf('%s_3_kspace_inv_ortho.nii',out_base);
if ~isempty(regexpi(mode,'volume'))
    img{1}=sprintf('%s_1_kspace%s.nii',out_base,'_re');
    img{4}=sprintf('%s_1_kspace%s.nii',out_base,'_im');
end
% setting this to less than nimages will prevent figure display
fig_start=-30;
work=numel(img);
for i_n=1:numel(img)
    if exist(img{i_n},'file')
        work=work-1;
    end
end
if ~work 
    disp('previews dumped');
    return;
end

original_dims=[size(data,1),size(original_mask)];
lil_dummy = zeros([1,1],'single');
lil_dummy = complex(lil_dummy,lil_dummy);
temp_data=zeros(original_dims,'like',lil_dummy);
% populate full array with all the data.
for n = 1:original_dims(1)
    temp_data(n,original_mask(:))=data(n,:);
end
% save basic kspace preview
if ~isempty(regexpi(mode,'volume'))
    save_nii(make_nii(real(temp_data)),img{1});
    save_nii(make_nii(imag(temp_data)),img{4});
else
    disp_vol_center(temp_data,1,fig_start+1,img{1});
end
%% get transform of ksapce to see base image.
temp_data=fftshift(fftshift(ifft(ifft(fftshift(fftshift(temp_data,2),3),[],2),[],3),2),3);
if ~isempty(regexpi(mode,'volume'))
    save_nii(make_nii(abs(temp_data)),img{2});
else
    disp_vol_center(abs(temp_data),0,fig_start+2,img{2});
end
%% invert transform again to see fully populated kspace
if exist(img{3},'file')
    return;
end
temp_data=fftshift(ifftn(fftshift(temp_data)));
%{
temp_data=fftshift(fftshift(fftshift(...
    ifft(ifft(ifft(...
    fftshift(fftshift(fftshift(temp_data,1),2),3)...
    ,[],1),[],2),[],3)...
    ,1),2),3);
%}
disp_vol_center(temp_data,1,fig_start+3,img{3});
end