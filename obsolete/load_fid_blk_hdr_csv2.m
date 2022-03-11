function b = load_blk_hdr(hdrpath,skip)
% Useful Ref: https://www.agilent.com/cs/library/usermanuals/Public/0199937900a.pdf
% ... note, unclear if original work
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
try
    fid = fopen(hdrpath,'r','ieee-be');
catch ME
    disp(ME)
end

if ~exist('skip','var')
skip=0;
end
fseek(fid,skip,'bof');
% First block header - for curiousity's (or coding progeny's) sake
b.scale= fread(fid,1,'int16');
b.status= fread(fid,1,'int16');
b.index= fread(fid,1,'int16');
b.mode= fread(fid,1,'int16');
b.ctcount = fread(fid,1,'int32');
b.lpval = fread(fid,1,'float32');
b.rpval = fread(fid,1,'float32');
b.lvl = fread(fid,1,'float32');
b.tlt = fread(fid,1,'float32');
% s_data    = bitget(status,1);



fclose(fid);

end
