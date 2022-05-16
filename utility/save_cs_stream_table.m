function out_file = save_cs_stream_table(mask,out_file,size_check_fail)
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
if ~exist('size_check_fail','var')
    size_check_fail=1;
end
pts=find(mask);
[d1,d2]=ind2sub(size(mask),pts);
% convert to +/- value
d1=d1-floor(size(mask,1)/2)-1;
d2=d2-floor(size(mask,2)/2)-1;
% reshape into stream
pt_data=reshape([d1';d2'],[numel(d1)+numel(d2),1]);
% cast appropriately
if max(size(mask))<= 2^7
    % this only worked because it was a 256x256 table
    %pt_data = pt_data - 2^7;
    pt_data=cast(pt_data,'int8');
elseif max(size(mask)) <= 2^15
    %pt_data = pt_data - 2^15;
    pt_data=cast(pt_data,'int16');
else
    error('mask data invalid, cannot proceed')
end
% size of the extended memory area we're using this with.
max_bytes=786432;
info=whos('pt_data');
if info.bytes > max_bytes
    if size_check_fail
        f=@error;
    else
        f=@warning;
    end
    f('too much data! you asked for %i bytes, but only %i is supported',info.bytes,max_bytes);
end
% we're writing a text file to be consumed by a special purpose reader.
fid=fopen(out_file,'w');
fprintf(fid,'%i\r\n',pt_data);
fclose(fid);

