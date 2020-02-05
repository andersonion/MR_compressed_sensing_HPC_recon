function [skiptable, dim2, dim3, pa, pb, ds_lvl] = extract_info_from_CStable(procpar_or_CStable,name_decode_only)
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
if ~exist('name_decode_only','var')
    name_decode_only=0;
end

% Determine if input is a procpar file or a CS_table
procpar=procpar_or_CStable;
full_CS_table_path = procpar_or_CStable; % Assume CStable by default.
if strcmp('procpar',procpar(end-6:end))
    % A procpar file should end in 'procpar' ( or be only procpar :D )
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
[t_var,CS_table_name]=fileparts(full_CS_table_path);
if ~exist('target_folder','var')
    target_folder = t_var;
end
clear t_var;
table_target = fullfile(target_folder,CS_table_name);
%% get info from the file name
% expected name format of CS tables
% Currently CS tables are square; future non-square tables should be named...
% with 'CS{dim2}x{dim3}_'... format. E.g.: 'CS256x184_'...
% CS0000_0x_pa00_pb00
% or CS0000x0000_0x_pa00_pb00
% ex
% CS256_8x_pa18_pb54
% CS256x256_8x_pa18_pb54

% current expected correct regex
cs_table_regex='CS([0-9]+)(x[0-9]+)?_([0-9]+([.][0-9]+)?)x_pa([0-9]+)_pb([0-9]+)';
% allowing for CSa, or CStable prefix
cs_table_regex='CS(?:a|table)?([0-9]+)(x[0-9]+)?_([0-9]+([.][0-9]+)?)x_pa([0-9]+)_pb([0-9]+)';
% allowing for additional prefix and _ after pa/pb
%cs_table_regex='CS(?:a|table)?([0-9]+)(x[0-9]+)?_([0-9]+([.][0-9]+)?)x_pa_?([0-9]+)_pb_?([0-9]+)';

regres=regexp(CS_table_name,cs_table_regex,'tokens');
regres=regres{1};
if numel(regres) ~=5
    error('failed to parse cstable name %s did not match regex %s',CS_table_name,cs_table_regex);
end
if ~exist('dim2','var')
    dim2=str2double(regres{1});
end
if ~exist('dim3','var')
    if isempty(regres{2})
        regres{2}=regres{1};
    end
    dim3=str2double(regres{2});
end
ds_lvl=str2double(regres{3});
pa=str2double(regres{4})/10;
pb=str2double(regres{5})/10;
if (~isnumeric(dim2) || ~isnumeric(dim3))
    error('Unable to derive numeric values for dim2 and/or dim3 from CStable:%s.',full_CS_table_path);
end
if name_decode_only
    skiptable=[];
    return;
end
if ~exist(table_target,'file')
    % Guess which scanner is the CStable source based on runno prefix
    [~,Tname]=fileparts(target_folder);
    if (strcmp(Tname(1),'N'))
        scanner = 'heike';
    else
        scanner = 'kamy';
    end
    % pull_table
    cmd = [ 'puller_simple  -o -f file ' scanner ' ''../../../../home/vnmr1/vnmrsys/tablib/' CS_table_name ''' ' target_folder];
    [skiptable,sout]=system(cmd); if skiptable~=0; warning(sout); end;clear cmd;
    if ~exist(table_target,'file')
        error('Unable to retrieve CS table: %s.', full_CS_table_path);
    end
end
%% cache handling for CS tables 
cache_folder=fullfile(getenv('WORKSTATION_DATA'),'petableCS');
[table_integrity,last_path]=cache_file(cache_folder,table_target);
if ~table_integrity
    warning('CS table was updated! Old file was preserved as %s',last_path);
    pause(3);
end


%% Open CS table and format into a bit mask (aka skiptable).
fid=fopen(table_target);
% potentially could use *char=>logical or uint.
skiptable=fread(fid,inf,'*char');
fclose(fid);
% convert to logical, and converts any unnecessary space chars to 0.
skiptable=(skiptable=='1');
%% enforce exact size
while numel(skiptable)<dim2*dim3
    % using a while is not necessary here, however if more than one 0 is
    % missing this will be extra spammy, which seems like a good thing.
    warning('TABLE UNDERSIZED! Adding 0''s to fill it out!');
    skiptable(end+1)=0;
end
if numel(skiptable)~= dim2*dim3
    warning('TABLE oversize! truncating! (You may have had trailing spaces converted to 0.)');
    skiptable=skiptable(1:dim2*dim3); % BJA - Trims off any zero padding
end
skiptable=reshape(skiptable,[dim2 dim3]);
end

