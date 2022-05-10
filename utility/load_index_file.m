function index_table = load_index_file(file_path)

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
