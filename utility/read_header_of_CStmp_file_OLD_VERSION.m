function [slices_complete, slices_remaining, full_header ] = read_header_of_CStmp_file_OLD_VERSION( temp_file,header_size )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
%header_size = dims(1); %*64; %the 64 is implied when we read in as double
if ~exist('header_size','var')
    header_size = dims(1); 
end


fid=fopen(temp_file,'r');
%work_done=fread(fid,header_size,'double')';
%if ~exist('header_size','var')
%    header_size = fread(fid,1,uint16);  % In version 2 the first uint16 element gives the length of the header.
%end

%work_done=fread(fid,header_size,'uint16')'; % 15 May 2017, BJA
work_done=fread(fid,header_size,'*uint8')';
fclose(fid);
slices_remaining = length(find(~work_done));
slices_complete = header_size - slices_remaining;
full_header=work_done;
end

