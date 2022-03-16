function [full_header, slices_with_work, slices_remaining, t_id] = load_cstmp_hdr( temp_file, varargin)
% [full_header, slices_completed, slices_remaining, file_handle ] = load_cstmp_hdr( temp_file,[file_mode])
% [full_header, slices_completed, slices_remaining, file_handle ] = load_cstmp_hdr( temp_file[[,file_mode]?[,retries][, header_size]?]?)
% 
% full_header = array N-compressed slices big
% slices_with_work = count of non-zero elements of full header
% slices_remaining = count of zero elements of full header
% file_handle = the file handle to continue reading, 
%   WARNING: if file handle requsted it must be closed! 
%            if not specified it will be closed normally.
% 
% temp_file = path to a temp file
% retries = how many attempts until we quit, 0 means 1 attempt with no
%           delay on fail, 1 means if first try fails, wait 30 seconds and
%           try again
% header_size = manually specified header size for files which dont use the
%               first element to specify size
% 
% SUMMARY: Returns status of an in-progres CS recon, by looking at the .tmp file in the work directory.
%   Written 14 September 2017, BJ Anderson, CIVM
% 
%   can be used inline for simple do work calls, 
%   ex if read_header...; disp('work complete'); else disp('do work');end
% NOTE this is opposition to former behavior of returned slice_remaining first, which could allow 
%   if ~read_header... ; disp('work complete'); else disp('do work');end
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

retries=0;

% find any character args to act as file_mode for fopen
for argn=1:numel(varargin)
    val=varargin{argn};
    if ischar(val)
        file_mode=val;
        varargin(argn)=[];
        break;
    end
end
argn=1;
if numel(varargin)>=argn
    retries=varargin{argn};argn=argn+1;
end
if numel(varargin)>=argn
    header_size=varargin{argn};argn=argn+1;
end
if ~exist('file_mode','var')
    file_mode='r';
end

t_id=fopen(temp_file,file_mode);
if ~exist('header_size','var')
      % In version 2 the first 2 bytes (first uint16 element) gives the length of the header.
    header_size = fread(t_id,1,'uint16');
end

if (header_size > 0 )
    full_header=fread(t_id,header_size,'uint16')';
    if nargout ~= 4
        fclose(t_id);
    end
    slices_remaining = length(find(~full_header));
    slices_with_work = header_size - slices_remaining;
elseif (header_size == 0 && retries > 0)
    fclose(t_id);
    pause(30);
    if nargout~=4
        [full_header,slices_with_work,slices_remaining]= ...
            load_cstmp_hdr(temp_file,file_mode,retries,header_size);
    else
        [full_header,slices_with_work,slices_remaining, t_id]= ...
            load_cstmp_hdr(temp_file,file_mode,retries,header_size);
    end
else
    fprintf(1,'ERROR: tmp file claims to have a zero-length header! This is not possible. DYING...\n\tTroublesome tmp file: %s.\n',temp_file);
    if isdeployed
        quit force;
    else
        error();
    end
end
end
