function missing=matfile_missing_vars(mat_file,varargin)
% function missing_count=matfile_missing_vars(mat_file,varlist)
% checks mat file for list of  vars,
% mat_file is the path to the .mat file,
% varlist is the comma separated list of expected variables, WATCH OUT FOR
% SPACES.

% if its a single cell 1ith 1 cell in it, unwrap it.
varlist=varargin;
if numel(varlist) == 1 && ( ~iscell(varargin{1}) || 1 < numel(varargin{1}) )
    varlist=varlist{1};
end

if ~iscell(varlist)
    varlist=strsplit(varlist,',');
end
missing=numel(varlist);
m_idx=zeros(size(varlist));
if ~exist(mat_file,'file');return; end
listOfVariables = who('-file',mat_file);
for v=1:numel(varlist)
    if ismember(varlist{v}, listOfVariables) % returns true
        missing = missing - 1;
    else
        m_idx(v)=1;
    end
end
end
