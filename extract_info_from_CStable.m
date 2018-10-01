function [skiptable, dim2, dim3, pa, pb] = extract_info_from_CStable(procpar_or_CStable)
%  
%   Pull skiptable (petableCS) information from Agilent procpar and
%   reconstruct as CS sampling mask.
%
%   % Input MUST be a full file path (not a naked CStable name)
%   % Hopefully a naked name will be supported in the future. 
%
%   % Currently CS tables are square; future non-square tables should be named...
%   % with 'CS{dim1}x{dim2}_'... format. E.g.: 'CS256x184_'...
%
%
%   Original code (skipint2skiptable.m) by Russell M. Dibb
%   Modified by BJ Anderson on 27 Oct 2016 to accomodate array sizes that
%   are not divisible by 32 (as "imposed" by procpar's 32-bit format).
%
%   Modified again by BJ Anderson on 13 Jan 2017 to be able to handle CS
%   tables directly.

% 18 September 2017 Revision (BJ Anderson, CIVM)
% Code Flow: 
%
% Determine if input is a procpar file or a CS_table
% -> If its a procpar file, make sure it exists (else throw ERROR)
% -> Assuming it exists, pull out CStable name (if not CStable specified, throw ERROR)
% -> Pull out dim_y and dim_z;
% 
% Now with CStable name in hand:
% Assume a copy belongs in workdir
% -> Check for existence (else pull from scanner)
% -> Recheck for existence (else throw ERROR)
% -> If dim_y and dim_z are not defined (from procpar file), derive from CS_table name
% 
% -> Check to see if dim_y and dim_z are numeric integers (else throw ERROR)
%
% Load CStable and process into a skiptable

% Determine if input is a procpar file or a CS_table
procpar=procpar_or_CStable;
full_CS_table_path = procpar_or_CStable; % Assume CStable by default.

test=strsplit(procpar,'.'); 
if strcmp('procpar',test{end}) % A procpar file should end in '.procpar'
    if ~exist(procpar,'file')
        error('Unable to find specified procpar file %s.', procpar);
    end
    
    pp = readprocparCS(procpar);
    if ~isfield(pp,'petableCS')
        e_string1='Cannot find field ''petableCS'' containing the path to the CStable in procpar file ''';
        e_string2='''; it is possible that this is not a compressed sending experiment.';
        error('%s%s%s',e_string1,procpar,e_string2);
    end
    
    % Get CStable path
    full_CS_table_path = pp.petableCS;
    full_CS_table_path=full_CS_table_path{1};
    
    target_folder = fileparts(procpar);
    
    % Get dim_y and dim_z (dim2/dim3)
    dim2 = pp.nv;
    dim3 = pp.nv2;
end

% Build path of local CStable and check for existence
CS_table_parts = strsplit(full_CS_table_path,'/');
CS_table_name = strtrim(CS_table_parts{end});

if ~exist('target_folder','var')
    target_folder = fileparts(full_CS_table_path);
end
table_target = [target_folder '/' CS_table_name];


if ~exist(table_target,'file')
    % Guess which scanner is the CStable source based on runno prefix
    split_target = strsplit(target_folder,'/');
    test_letter = split_target{end}(1);
    target_folder = [target_folder '/'];
    if (strcmp(test_letter,'N'))
        scanner = 'heike';
    else
        scanner = 'kamy';
    end
    % pull_table initially was wrapped in an ssh call.
    % that is bad form, and makes a spagetti mess.
    pull_table_cmd = [ 'puller_simple  -o -f file ' scanner ' ''../../../../home/vnmr1/vnmrsys/tablib/' CS_table_name ''' ' target_folder];
    system(pull_table_cmd)
    
    if ~exist(table_target,'file')
        error('Unable to retrieve CS table: %s.', full_CS_table_path);
    end
    
end

if (~exist('dim2','var') || ~exist('dim3','var'))
    split_t_name = strsplit(CS_table_name,'_');
    split_t_name = split_t_name{1}(3:end); % Removes 'CS' prefix.
    dims_23 = strsplit(split_t_name,'x'); % Currently CS tables are square; future non-square tables should be named...
    % with 'CS{dim1}x{dim2}_'... format. E.g.: 'CS256x184_'...
    if (length(dims_23) == 1)
        dims_23 = [dims_23 dims_23];
    else
        dims_23 = dims_23(1:2);
    end
    dims_23 = str2double(dims_23);
    
    dim2 = dims_23(1);
    dim3 = dims_23(2);
end

if (~isnumeric(dim2) || ~isnumeric(dim3))
    error('Unable to derive numeric values for dim2 and/or dim3 from CStable:%s.',full_CS_table_path);
end


% Open CS table and format into a bit mask (aka skiptable).
table_target =strtrim(table_target);
fid=fopen(table_target);
s=fread(fid,inf,'*char');
fclose(fid);


s = reshape(s',[length(s(:)) 1]); % BJA - Not always dependent on array size.
s = str2num(s); % Note str2doulbe will NOT work.
s=s(1:dim2*dim3); % BJA - Trims off any zero padding

skiptable = logical(reshape(s,[dim2 dim3]));

% Get pa and pb from table name
pieces = strsplit(CS_table_name,'_pa');
pa_pb = strsplit(pieces{2},'_pb');
pa=str2double(pa_pb{1})/10;
pb=str2double(pa_pb{2})/10;

end

