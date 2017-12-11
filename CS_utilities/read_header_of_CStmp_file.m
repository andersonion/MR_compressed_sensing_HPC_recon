function [slices_remaining, slices_completed, full_header ] = read_header_of_CStmp_file( temp_file,header_size_or_quick_check)
%% SUMMARY: Returns status of an in-progres CS recon, by looking at the .tmp file in the work directory.
%   Written 14 September 2017, BJ Anderson, CIVM
%   slice_remaining is returned first, thus acting by itself as an exit
%   code of 0->'success;

%if ~exist('header_size','var')
%    header_size = dims(1);
%end
quick_check=0;
if exist('header_size_or_quick_check','var')
    if iscell(header_size_or_quick_check)
        quick_check=header_size_or_quick_check{2};
        if ~isempty(header_size_or_quick_check{1})
            header_size=header_size_or_quick_check{1};
        end
    else
        header_size=header_size_or_quick_check;
    end
end
fid=fopen(temp_file,'r');
%work_done=fread(fid,header_size,'double')';
if ~exist('header_size','var')
    header_size = fread(fid,1,'uint16');  % In version 2 the first 2 bytes (first uint16 element) gives the length of the header.
end
if (header_size == 0)
    fclose(fid);
    if quick_check == 0
        pause(30);
    end
    fid=fopen(temp_file,'r');
    header_size = fread(fid,1,'uint16');
    if (header_size == 0)
        fclose(fid);
        % Why not just use the "error" function instead of a fprintf and a
        % broken status?
        fprintf(1,'ERROR: tmp file claims to have a zero-length header! This is not possible. DYING...\n\tTroublesome tmp file: %s.\n',temp_file);
        status=this_undefined_variable_will_return_a_goddamn_error_code;
    end
end
work_done=fread(fid,header_size,'uint16')';
fclose(fid);
slices_remaining = length(find(~work_done));
slices_completed = header_size - slices_remaining;
full_header=work_done;
end
