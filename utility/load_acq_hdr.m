function [hdr,S_hdr]= load_acq_hdr(the_scanner,data_file)
% function [hdr,raw_hdr]= load_acq_hdr(the_scanner,data_file)
% the_scanner is a scanner settings object
% data_File is the path to a local file
% multi-sys header loader to start by supporting agilent & mrsolutions
% becuase our recon is purematlab we are implementing this in matlab instead of perl
%
% load header only from data file and return a uniform structure
% 
% structure elements
% ray_length - length of one ray value is same even if complex
% rays_per_block - count of rays in one block of rays
% ray_blocks - total blocks of rays
% rays_acquired_in_total - total rays acquired 
% bytes_per_block - total bytes in one block of rays
% bytes_per_point - bytes per point(before accounting for complex numbers)
% data_type - matlab type name
% data_is_complex - is data real numbers or complex-numbers
hdr=struct;
if strcmp(the_scanner.vendor,'agilent')
    % if need be we can also add the_scanner.header_type
    S_hdr=load_fid_hdr(data_file);
    % agilent dataorder is 
    % readout, echos, combined-compressed-phase, volumes
    % becuase c for channel makes sense, lets not use that
    % becuase p for param (as in varhing some parameter) makes sense, lets skip that too
    % Phase for phase, at least for now.
    % should we use d for diffusion instead t for time?
    % probably not becuase its not evident that we have diffusion data from
    % just the acq header
    % how about we keep it in neurtal terms, "blocks"
    % 
    hdr.dims=dimstruct('xPb',[S_hdr.file.npoints/2, S_hdr.file.ntraces, S_hdr.file.nblocks]);
    hdr.ray_length=double(S_hdr.file.npoints/2);
    hdr.rays_per_block=double(S_hdr.file.ntraces);
    hdr.ray_blocks=double(S_hdr.file.nblocks);
    hdr.rays_acquired_in_total=double(hdr.ray_blocks*hdr.rays_per_block);
    % we dont know the following values yet
    %   ray_blocks_per_volume
    %   rays_per_volume
    % elsewhere we'll presume ray_block_per_volume=1 if its not set but
    % we wont set it to avoid propagating bad guesses
    %

    %{
ray_length
rays_per_block
ray_blocks
rays_acquired_in_total

ray_blocks_per_volume
rays_per_volume

    %}

    %{
% n_sampled_lines is evident in the CS mask, but NOT in the hdr itself
% so we cant do this math here without more information.
% its possible it'll be evident becuase of ntraces, but we'll shelve this
% problem for now

    m.nechoes = 1;
    if (m.nblocks == 1)
        % Shouldn't need to round...just being safe.
        m.nechoes = round(m.ntraces/m.n_sampled_lines);
        m.n_volumes = m.nechoes;
    else
        m.n_volumes = m.nblocks;
    end
    %}
    if hdr.ray_blocks == 1
        error('first one block data, didnt handle all cases');
    end
    acq_st=S_hdr.file.acq_status;
    if acq_st.float32==1
        hdr.data_type='single';
        hdr.bytes_per_point = 4;
    elseif acq_st.int32==1
        hdr.bitdepth='int32';
        hdr.bytes_per_point = 4;
    elseif ~isempty(acq_status)
        hdr.bitdepth='int16';
        hdr.bytes_per_point = 2;
    else
        %    hdr.bitdepth=[];
        %    hdr.bytes_per_point=[];
    end
    hdr.bytes_per_block=S_hdr.file.bytes_per_block;
    %hdr.bytes_per_ray=S_hdr.file.bytes_per_trace;
    % agilent data is complex bit's appear incorrect. will try to infer
    %
    hdr.data_is_complex=0;
    if S_hdr.file.bytes_per_trace/S_hdr.file.bytes_per_element/hdr.ray_length==2
        hdr.data_is_complex=1;
    end
    % what about procpar and all that! that could be specified here too...
    % blargh
    % lets start with ultra minimum
elseif strcmp(the_scanner.vendor,'mrsolutions')
    % in theory load_mrd is cool enough to skip loading data if you didnt
    % ask for it.
    S_hdr=load_mrd(data_file);
    %hdr.dims=dimstruct('xyzpt',hdr.Dimension);
    % header dimensions are constant in mrd fiels, but i suspect their
    % order is bs.
    % they are spatial 1, 2, slices, spatial 3, echos, experiments.
    % the expectation is that slices and spatial 3 will not both exist at
    % the same time
    hdr.dims=dimstruct('xyszet',hdr.Dimension);
    hdr.data_is_complex=S_hdr.data_is_complex;
    hdr.data_type=S_hdr.data_type;
    hdr.ray_length=double(S_hdr.Dimension(1));
    % a guess...
    % hdr.rays_per_block=double(S_hdr.Dimension(2));
    error('incomplete');
else
    error('unrecognized scanner_vendor:%s',the_scanner.vendor);
end

% P is compresed sensing, which is a spatial dimension
spatial_dims='xyzP';
%{
% no guarntee it is only one ray-block per volmue, so this calculation is
pre-mature
nsd=hdr.dims.Rem(spatial_dims);
hdr.n_volumes=prod(hdr.dims.Sub(nsd));
%}
% the capitol dims should ONLY be xyz, anything else has to remain in the
% dim struct
spatial_dims(spatial_dims=='P')=[];
for dn=1:numel(spatial_dims)
    % dim char
    dc=spatial_dims(dn);
    % dim name
    d_name=sprintf('dim_%s',upper(dc));
    %dim_value
    dv=hdr.dims.Sub(dc);
    if dv~=0
        hdr.(d_name)=dv;
    end
end
end