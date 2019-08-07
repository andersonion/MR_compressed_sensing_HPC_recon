function [npoints,nblocks,ntraces,bitdepth,bytes_per_block,complete_file_size,b_status] = load_fid_hdrCS(fidpath)
% Useful Ref: https://www.agilent.com/cs/library/usermanuals/Public/0199937900a.pdf
try
    fid = fopen(fidpath,'r','ieee-be');
catch ME
    disp(ME)
end

% Read datafileheader
nblocks   = fread(fid,1,'int32');
ntraces   = fread(fid,1,'int32');
npoints   = fread(fid,1,'int32');
bytes_per_element     = fread(fid,1,'int32');
bytes_per_trace    = fread(fid,1,'int32');
bytes_per_block     = fread(fid,1,'int32');
version_id     = fread(fid,1,'int16');
status    = fread(fid,1,'int16');
n_block_headers_per_block   = fread(fid,1,'int32');

% First block header - for curiousity's (or coding progeny's) sake
b_scale= fread(fid,1,'int16');
b_status= fread(fid,1,'int16');
b_index= fread(fid,1,'int16');
b_mode= fread(fid,1,'int16');
b_ctcount = fread(fid,1,'int32');
b_lpval = fread(fid,1,'float32');
b_rpval = fread(fid,1,'float32');
b_lvl = fread(fid,1,'float32');
b_tlt = fread(fid,1,'float32');


%get bitdepth
s_32      = bitget(status,3);
s_float   = bitget(status,4);

if s_32==1
    bitdepth='int32';
    bytes_per_point = 4;
elseif s_float==1
    bitdepth='float32';
    bytes_per_point = 4;
else
    bitdepth='int16';
    bytes_per_point = 2;
end


complete_file_size=32+nblocks*bytes_per_block;

fclose(fid);

end