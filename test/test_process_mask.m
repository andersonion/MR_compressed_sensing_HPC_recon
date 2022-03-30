% test skipint2skiptable 
% test loading up cs table
t='D:\ProjectSpace\jjc29\mrsolutions\to_mr_solutions\CS256_8x_pa18_pb54';
%skip_table=skipint2skiptable(t);
o=struct;
o.hamming_window=32;
[dim_y, dim_z, n_sampled_lines, sampling_fraction, mask, ...
    CSpdf, phmask, recon_dims, original_mask, original_pdf, original_dims] ...
    = process_CS_mask(t,200,o);
