function save_cs_stream_table(mask,out_file)
% function SAVE_CS_STREAM_TABLE(mask,out_file)
% saves a 2D cs table as a text file of co-ordinate pairs
% each line is a single part of the co ordinate pair
%
% Copyright Duke University
% Authors: James J Cook, G Allan Johnson
if exist(out_file,'file')
    warning('existing table, WILL NOT overwrite');
    return;
end

pts=find(mask);
[d1,d2]=ind2sub(size(mask),pts);
pt_data=reshape([d1';d2'],[numel(d1)+numel(d2),1]);

% convert to +/- value
if max(size(mask))<= 2^8
    pt_data = pt_data - 2^7;
    pt_data=cast(pt_data,'int8');
elseif max(size(mask)) <= 2^16
    pt_data = pt_data - 2^15;
    pt_data=cast(pt_data,'int16');
end
% size of the extended memory area we're using this with.
max_bytes=786432;
info=whos('pt_data');
if info.bytes > max_bytes
    error('too much data! you asked for %i bytes, but only %i is supported',info.bytes,max_bytes);
end
% we're writing a text file to be consumed by a special purpose reader.
fid=fopen(out_file,'w');
fprintf(fid,'%i\r\n',pt_data);
fclose(fid);

