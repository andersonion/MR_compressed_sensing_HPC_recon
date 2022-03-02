function [table_dims,pa,pb,cs_factor]=cs_table_name_decode(cs_table)
% function [mask_size,pa,pb,cs_factor]=CS_TABLE_NAME_DECODE(cs_table)
% Copyright Duke University
% Authors: James J Cook, G Allan Johnson
%%%
% get info from the file name
%%%
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

regres=regexp(cs_table,cs_table_regex,'tokens');
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
table_dims=[dim2,dim3];
cs_factor=str2double(regres{3});
pa=str2double(regres{4})/10;
pb=str2double(regres{5})/10;
if (~isnumeric(dim2) || ~isnumeric(dim3))
    error('Unable to derive numeric values for dim2 and/or dim3 from CStable:%s.',full_CS_table_path);
end
