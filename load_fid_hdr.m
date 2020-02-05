function [npoints,nblocks,ntraces,bitdepth,bytes_per_block,complete_file_size, ...
    blk_hdr] = load_fid_hdr(fidpath)
%  [npoints,nblocks,ntraces,bitdepth,bytes_per_block,complete_file_size,blk_hdr] = load_fid_hdr_details(fidpath)
% Useful Ref:
% https://www.agilent.com/cs/library/usermanuals/Public/0199937900a.pdf
% page 275
try
    fid = fopen(fidpath,'r','ieee-be');
catch ME
    error(ME.msg)
end
if fid<0
    error('Trouble opening file %s',fidpath);
end

% Read datafileheader
nblocks   = fread(fid,1,'int32');
ntraces   = fread(fid,1,'int32');
npoints   = fread(fid,1,'int32'); % fomerly np

%{
% old code used terse and hard to understand names
np        = fread(fid,1,'int32');
ebytes    = fread(fid,1,'int32');
tbytes    = fread(fid,1,'int32');
bbytes    = fread(fid,1,'int32');
vers_id   = fread(fid,1,'int16');
status    = fread(fid,1,'int16');
nbheaders = fread(fid,1,'int32');
%}

bytes_per_element = fread(fid,1,'int32'); % formerly ebytes
bytes_per_trace   = fread(fid,1,'int32'); % formerly tbytes

% Out of spec (should be int32) because we may have integer overflow (>2,147,483,647)
% Changing to uint32 will still always return the right number in the
% common (valid) range of 0 to 2,147,483,647.
bytes_per_block   = fread(fid,1,'uint32'); % formerly bbytes

% I think version here refers to a data spec version.
% We've only seen 0
version_id        = fread(fid,1,'int16'); % formerly vers_id
% This is acq status, a complex bin array of things. see below
acq_status        = fread(fid,1,'int16'); % formerly status
n_block_headers_per_block   = fread(fid,1,'int32'); % formerly nbheaders

% First block header - for curiousity's (or coding progeny's) sake
blk_hdr.scale  = fread(fid,1,'int16');
blk_hdr.status = fread(fid,1,'int16');
blk_hdr.index  = fread(fid,1,'int16');
blk_hdr.mode   = fread(fid,1,'int16');
blk_hdr.ctcount = fread(fid,1,'int32');
blk_hdr.lpval  = fread(fid,1,'float32');
blk_hdr.rpval  = fread(fid,1,'float32');
blk_hdr.lvl    = fread(fid,1,'float32');
blk_hdr.tlt    = fread(fid,1,'float32');

%get bitdepth 
acq_st.data    = bitget(acq_status,1);
acq_st.spec    = bitget(acq_status,2);
acq_st.int32   = bitget(acq_status,3);
acq_st.float   = bitget(acq_status,4);
acq_st.complex = bitget(acq_status,5);
acq_st.hyper   = bitget(acq_status,6);

fclose(fid);

if acq_st.int32==1
    bitdepth='int32';
    bytes_per_point = 4;
elseif acq_st.float==1
    bitdepth='float32';
    bytes_per_point = 4;
else
    bitdepth='int16';
    bytes_per_point = 2;
end
% bytes_per_point should agree with bytes per element
if bytes_per_element ~= bytes_per_point
    warning('bitdepth detection may have failed');
end
% What is this 32 doing here? What does that represent?
% I think its the constant size file header
%header_size=32; %agilent file headers are always 32 bytes big.
complete_file_size=32+nblocks*bytes_per_block;
%block_header=28; %agilent block headers are 28 bytes big. 


end