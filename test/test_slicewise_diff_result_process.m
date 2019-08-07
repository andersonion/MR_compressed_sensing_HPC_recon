%% compare res 
% started each code with tempfile, got to point where we'd have res, and
% loaded it, then saved as old_res and new_res .mat
%or=load('old_res','res');
%nr=load('new_res','res');

%% load res data
res_slice.(['s' s_idx])=cell(size(function_versions));
for fv=1:numel(function_versions)
    load(test_workspace{fv},'aux_param')
    tf=aux_param.tempFile;
    disp(aux_param.tempFile(end-30:end));
    res_slice.(['s' s_idx]){fv}=CS_tmp_load(tf,aux_param.recon_dims,str2double(s_idx));
    clear aux_param tf;
end
%% load comparison data

load(test_workspace{fv},'aux_param')
tf=tmp_replicate;
res_slice_iter_stream.(['s' s_idx])=CS_tmp_load(tf,aux_param.recon_dims,str2double(s_idx));
%% compare via subtraction
is_sum=sum(abs(res_slice_iter_stream.(['s' s_idx])(:)));
fprintf('iter_stream sum %g\n',is_sum);
for fv=1:numel(function_versions)
    tslice=res_slice_iter_stream.(['s' s_idx])-res_slice.(['s' s_idx]){fv};
    r_sum=sum(abs(res_slice.(['s' s_idx]){fv}(:)));
    fprintf('function %s\n',function_versions{fv});
    fprintf('\tsum %g ',sum(tslice(:)));
    fprintf('abs(sum()) = %g\t\n',abs(sum(tslice(:))));
    fprintf('res_slice sum %g\n',r_sum);
end
