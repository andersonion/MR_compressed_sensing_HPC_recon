function [dim_y, dim_z, n_sampled_lines, sampling_fraction, mask, ...
    CSpdf,phmask,recon_dims,original_mask,original_pdf,original_dims]= ...
    process_CS_mask(procpar_or_CStable,dim_x,options)
% function process_CS_mask 
fprintf('process_CS_mask ... this can take a minute.\n');
[mask, dim_y, dim_z, pa, pb ] = extract_info_from_CStable(procpar_or_CStable);
n_sampled_lines=sum(mask(:));
sampling_fraction = n_sampled_lines/length(mask(:));
original_dims = double([dim_x dim_y dim_z]);
% Generate sampling PDF (this is not the sampling mask)
[CSpdf,~] = genPDF_wn_v2(original_dims(2:3),pa,sampling_fraction,pb,false);
original_mask = mask;
original_pdf = CSpdf;
% pad if non-square or non-power of 2
dyadic_idx = 2.^(1:14); %dyadic_idx = 2.^[1:12]; %%%% 12->14
pidx = find(max(original_dims(2:3))<=dyadic_idx,1);
p = 2^pidx;
if (p>max(original_dims(2:3)))
    mask = padarray(original_mask,[p-original_dims(2) p-original_dims(3)]/2,0,'both');
    CSpdf = padarray(CSpdf,[p-original_dims(2) p-original_dims(3)]/2,1,'both'); %pad with 1's since we don't want to divide by zero later
end
recon_dims = [original_dims(1) size(mask)];%size(data);

phmask = zpad(hamming(options.hamming_window)*hamming(options.hamming_window)',recon_dims(2),recon_dims(3)); %mask to grab center frequency
phmask = phmask/max(phmask(:));			 %for low-order phase estimation and correction
end
