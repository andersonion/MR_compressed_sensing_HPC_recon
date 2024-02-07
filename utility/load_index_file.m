function index_table = load_index_file(file_path,base_directory)

opts=delimitedTextImportOptions('Whitespace',sprintf('\t '),...
    'Delimiter', {sprintf('\t'),' '}, ...
    'VariableNames',{'index','fid'}, ...
    'VariableTypes',{'uint64','char'} ...
    );
index_table = readtable(file_path,opts);

% check that we have contiguous numbers in the index field(note starting
% from 0, maybe that should be variable
idx_test=0:size(index_table,1)-1;
if nnz(index_table.index(:)~=idx_test(:))
    error('index file error, non-contiguous');
end


if exist('base_directory','var') && ~path_is_absolute(index_table.fid{1})
    % local_index.fid = cellfun(@(c) fullfile(scan_data_setup.main,c), local_index.fid)
    idx_ready = cellfun(@(c) ~isempty(c),index_table.fid);
    full_paths = cellfun(@(c) fullfile(base_directory,c), index_table.fid, 'UniformOutput', false);
    full_paths =cellfun(@(c) path_convert_platform(c,'lin'), full_paths ,'UniformOutput',false);
    index_table.fid(idx_ready) = full_paths(idx_ready);
end
