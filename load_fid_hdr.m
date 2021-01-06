function [npoints,nblocks,ntraces,bitdepth,bytes_per_block,complete_file_size, ...
    blk_hdr,full_hdr] = load_fid_hdr(fidpath)
%  [npoints,nblocks,ntraces,bitdepth,bytes_per_block,complete_file_size,blk_hdr,header_struct] = load_fid_hdr_details(fidpath)
% Useful Ref: (note not for the current version)
% https://www.agilent.com/cs/library/usermanuals/Public/0199937900a.pdf
% page 275
% https://www.agilent.com/cs/library/usermanuals/public/0199925300a.pdf
% page 264
% header_struct tries to be the elements in order, such that if written
% back to file it would re-create the structure correctly.
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

try
    fid = fopen(fidpath,'r','ieee-be');
catch ME
    error(ME.msg)
end
if fid<0
    error('Trouble opening file %s',fidpath);
end

%{
% Current guide (Agilent4.0 USER PROGRAMMING Reference Guide.pdf)
% Data file section starts pg 440.
% Relevant extract from pg 443-446
struct datafilehead
/* Used at start of each data file (FIDs, spectra, 2D) */
{
long nblocks; /* number of blocks in file */
long ntraces; /* number of traces per block */
long np; /* number of elements per trace */
long ebytes; /* number of bytes per element */
long tbytes; /* number of bytes per trace */
long bbytes; /* number of bytes per block */
short vers_id; /* software version, file_id status bits
*/
short status; /* status of whole file */
long nbheaders; /* number of block headers per block */
};
The variables in datafilehead structure are set as follows:
 nblocks is the number of data blocks present in the file.
 ntraces is the number of traces in each block.
 np is the number of simple elements (16-bit integers,
32-bit integers, or 32-bit floating point numbers) in one
trace. It is equal to twice the number of complex data
points.
 ebytes is the number of bytes in one element, either 2
(for 16-bit integers in single precision FIDs) or 4 (for all
others).
 tbytes is set to ( np*ebytes ).
 bbytes is set to ( ntraces*tbytes +
nbheaders*sizeof(struct datablockhead) ). The size of
the datablockhead structure is 28 bytes.
 vers_id is the version identification of present VnmrJ.
 nbheaders is the number of block headers per data block.
 status is bits as defined below with their hexadecimal
values.
All other bits must be zero.
* If S_FLOAT=0, S_32=0 for 16-bit integer, or S_32=1 for
32-bit integer.
If S_FLOAT=1, S_32 is ignored.
Table 47 Bits 06: file header and block header status bits (bit 6 is
unused)
0 S_DATA 0x1 0 = no data, 1 = data
1 S_SPEC 0x2 0 = FID, 1 = spectrum
2 S_32 0x4 *
3 S_FLOAT 0x8 0 = integer, 1 = floating
point
4 S_COMPLEX 0x10 0 = real, 1 = complex
5 S_HYPERCOMPLEX 0x20 1 = hypercomplex
Table 48 Bits 7-14: file header status bits (bits 10 and 15 are unused)
7 S_ACQPAR 0x80 0 = not Acqpar, 1 = Acqpar
8 S_SECND 0x100 0 = first FT, 1 = second FT
9 S_TRANSF 0x200 0 = regular, 1 = transposed
11 S_NP 0x800 1 = np dimension is active
12 S_NF 0x1000 1 = nf dimension is active
13 S_NI 0x2000 1 = ni dimension is active
14 S_NI2 0x4000 1 = ni2 dimension is active
Parameters and Data 5
VnmrJ 4 User Programming 445
Block headers are defined by the following C specifications:
struct datablockhead
/* Each file block contains the following header */
{
short scale; /* scaling factor */
short status; /* status of data in block */
short index; /* block index */
short mode; /* mode of data in block */
long ctcount; /* ct value for FID */
float lpval; /* f2 (2D-f1) left phase in phasefile */
float rpval; /* f2 (2D-f1) right phase in phasefile */
float lvl; /* level drift correction */
float tlt; /* tilt drift correction */
};
status is bits 0-6 defined the same as for file header status.
Bits 7-11 are defined below (all other bits must be zero):
Additional data block header for hypercomplex 2D data:
struct hypercmplxbhead
{
short s_spare1; /* short word: spare */
short status; /* status word for block header */
short s_spare2; /* short word: spare */
short s_spare3; /* short word: spare */
long l_spare1; /* long word: spare */
float lpval1; /* 2D-f2 left phase */
float rpval1; /* 2D-f2 right phase */
float f_spare1; /* float word: spare */
float f_spare2; /* float word: spare */
};
Table 49 Bits 7-11
7 MORE_BLOCKS 0x80 0 = absent, 1 = present
8 NP_CMPLX 0x100 0 = real, 1 = complex
9 NF_CMPLX 0x200 0 = real, 1 = complex
10 NI_CMPLX 0x400 0 = real, 1 = complex
11 NI2_CMPLX 0x800 0 = real, 1 = complex


Main data block header mode bits 0-15:
The actual FID data are typically stored as pairs of
floating-point numbers. The first represents the real part of
a complex pair and the second represents the imaginary
component. In phase-sensitive 2D experiments, "X" and "Y"
experiments are similarly interleaved. The format of the data
points and the organization as complex pairs must be
specified in the data file header.
Table 50 Bits 0-3: bit 3 is currently unused
0 NP_PHMODE 0x1 1 = ph mode
1 NP_AVMODE 0x2 1 = av mode
2 NP_PWRMODE 0x4 1 = pwr mode
Table 51 Bits 4-7: bit 7 is currently unused
4 NF_PHMODE 0x10 1 = ph mode
5 NF_AVMODE 0x20 1 = av mode
6 NF_PWRMODE 0x40 1 = pwr mode
Table 52 Bits 8-11: bit 11 is currently unused
8 NI_PHMODE 0x100 1 = ph mode
9 NI_AVMODE 0x200 1 = av mode
10 NI_PWRMODE 0x400 1 = pwr mode
Table 53 Bits 12-15: bit 15 is currently unused
12 NI2_PHMODE 0x8 1 = ph mode
13 NI2_AVMODE 0x100 1 = av mode
14 NI2_PWRMODE 0x2000 1 = pwr mode
Table 54 Usage bits for additional block headers
(hypercmplxbhead.status)
U_HYPERCOMPLEX 0x2 1 = hypercomplex block structure

%}


% Read datafileheader
nblocks   = fread(fid,1,'int32=>int32');
ntraces   = fread(fid,1,'int32=>int32');
npoints   = fread(fid,1,'int32=>int32'); % fomerly np

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

bytes_per_element = fread(fid,1,'int32=>int32'); % formerly ebytes
bytes_per_trace   = fread(fid,1,'int32=>int32'); % formerly tbytes

% Out of spec (should be int32) because we may have integer overflow (>2,147,483,647)
% Changing to uint32 will still always return the right number in the
% common (valid) range of 0 to 2,147,483,647.
bytes_per_block   = fread(fid,1,'uint32=>uint32'); % formerly bbytes

% I think version here refers to a data spec version.
% We've only seen 0
version_id        = fread(fid,1,'int16=>int16'); % formerly vers_id
% This is acq status, a complex bin array of things. see below
acq_status        = fread(fid,1,'int16=>int16'); % formerly status
n_block_headers_per_block   = fread(fid,1,'int32=>int32'); % formerly nbheaders

% First block header - for curiousity's (or coding progeny's) sake
%{
short scale; /* scaling factor */
short status; /* status of data in block */
short index; /* block index */
short mode; /* mode of data in block */
long ctcount; /* ct value for FID */
float lpval; /* f2 (2D-f1) left phase in phasefile */
float rpval; /* f2 (2D-f1) right phase in phasefile */
float lvl; /* level drift correction */
float tlt; /* tilt drift correction */
%}
blk_hdr.scale  = fread(fid,1,'int16=>int16');
blk_hdr.status = fread(fid,1,'int16=>int16');
blk_hdr.index  = fread(fid,1,'int16=>int16');
blk_hdr.mode   = fread(fid,1,'int16=>int16');
blk_hdr.ctcount = fread(fid,1,'int32=>int32');
blk_hdr.lpval  = fread(fid,1,'float32=>float32');
blk_hdr.rpval  = fread(fid,1,'float32=>float32');
blk_hdr.lvl    = fread(fid,1,'float32=>float32');
blk_hdr.tlt    = fread(fid,1,'float32=>float32');
fclose(fid);

%% parse status flags, including get bitdepth flags
%{
Table 47 Bits 0-6: file header and block header status bits (bit 6 is
unused)
0 S_DATA 0x1 0 = no data, 1 = data
1 S_SPEC 0x2 0 = FID, 1 = spectrum
2 S_32 0x4 *
3 S_FLOAT 0x8 0 = integer, 1 = floating
point
4 S_COMPLEX 0x10 0 = real, 1 = complex
5 S_HYPERCOMPLEX 0x20 1 = hypercomplex
6 UNUSED6
Table 48 Bits 7-14: file header status bits (bits 10 and 15 are unused)
7 S_ACQPAR 0x80 0 = not Acqpar, 1 = Acqpar
8 S_SECND 0x100 0 = first FT, 1 = second FT
9 S_TRANSF 0x200 0 = regular, 1 = transposed
11 S_NP 0x800 1 = np dimension is active
10 UNUSED10
12 S_NF 0x1000 1 = nf dimension is active
13 S_NI 0x2000 1 = ni dimension is active
14 S_NI2 0x4000 1 = ni2 dimension is active
15 UNUSED15
%}

acq_st_elements={
'hasData' %0 'S_DATA'
'isSpectrum' %1 'S_SPEC'
'int32' %2 'S_32'
'float32' %3 'S_FLOAT'
'S_COMPLEX' %4
'S_HYPERCOMPLEX' %5
'UNUSED6' %6
'S_ACQPAR' %7
'S_SECND' %8
'S_TRANSF' %9
'S_NP' %10
'UNUSED10' %11
'S_NF' %12
'S_NI' %13
'S_NI2' %14
'UNUSED15' %15
};
%{
acq_st.data    = logical(bitget(acq_status,1));
acq_st.spec    = logical(bitget(acq_status,2));
acq_st.int32   = logical(bitget(acq_status,3));
acq_st.float   = logical(bitget(acq_status,4));
acq_st.complex = logical(bitget(acq_status,5));
acq_st.hyper   = logical(bitget(acq_status,6));
%}
for abit=1:numel(acq_st_elements)
    acq_st.(acq_st_elements{abit})   = logical(bitget(acq_status,abit));
end

if acq_st.float32==1
    bitdepth='float32';
    bytes_per_point = 4;
elseif acq_st.int32==1
    bitdepth='int32';
    bytes_per_point = 4;
elseif ~isempty(acq_status)
    bitdepth='int16';
    bytes_per_point = 2;
else
    bitdepth=[];
    bytes_per_point=[];
end

%% blk hdr status flags
%{
Table 49 Bits 7-11
7 MORE_BLOCKS 0x80 0 = absent, 1 = present
8 NP_CMPLX 0x100 0 = real, 1 = complex
9 NF_CMPLX 0x200 0 = real, 1 = complex
10 NI_CMPLX 0x400 0 = real, 1 = complex
11 NI2_CMPLX 0x800 0 = real, 1 = complex
%}

acq_st_elements(8:16)={
'MORE_BLOCKS' %7 0x80 0 = absent, 1 = present
'NP_CMPLX' %8 0x100 0 = real, 1 = complex
'NF_CMPLX' %9 0x200 0 = real, 1 = complex
'NI_CMPLX' %10 0x400 0 = real, 1 = complex
'NI2_CMPLX' %11 0x800 0 = real, 1 = complex
'UNUSED12' %12
'UNUSED13' %13
'UNUSED14' %14
'UNUSED15' %15
};

for abit=1:numel(acq_st_elements)
    acq_stb.(acq_st_elements{abit})   = logical(bitget(blk_hdr.status,abit));
end
blk_hdr.status=acq_stb;

% bytes_per_point should agree with bytes per element
if bytes_per_element ~= bytes_per_point
    warning('bitdepth detection may have failed');
end
% What is this 32 doing here? What does that represent?
% I think its the constant size file header
%header_size=32; %agilent file headers are always 32 bytes big.
complete_file_size=32+double(nblocks)*double(bytes_per_block);
%block_header=28; %agilent block headers are 28 bytes big. 
full_hdr.file.nblocks=nblocks;
full_hdr.file.ntraces=ntraces;
full_hdr.file.npoints=npoints;
full_hdr.file.bytes_per_element=bytes_per_element;
full_hdr.file.bytes_per_trace=bytes_per_trace;
full_hdr.file.bytes_per_block=bytes_per_block;
full_hdr.file.version_id=version_id;
full_hdr.file.acq_status=acq_st;
full_hdr.file.nblock_headers_per_block=n_block_headers_per_block;
full_hdr.block_one=blk_hdr;

end
