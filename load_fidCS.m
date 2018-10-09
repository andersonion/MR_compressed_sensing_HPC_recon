function data_buffer = load_fidCS(fidpath,max_blocks,ntraces,npoints,bitdepth,cyclenum,voldims,only_non_zeros,double_down)


%5 May 2017, BJA: Added only_non_zeros flag, which only pulls out acquired
%data and arranges it in a 2D array, where dim1 is the fully sampled
%read-out direction, and dim2 is the non-zero elements of the vectorized
%mask.

%16 May 2017, BJA: Added double_down flag, which will treat the data as
%double from the beginning, instead of wasting memory space doing it
%seperately later (hope this works!).


if ~exist('only_non_zeros','var')
    only_non_zeros = 0; 
end

if ~exist('double_down','var')
    % Double_down is inherrently silly. This would be MUCH BETTER if it was
    % just a string, with a value of either single or double. 
    double_down = 0; 
end


try
    fid = fopen(fidpath,'r','ieee-be');
catch ME
    disp(ME)
end


%find out how many bytes per point
if strcmp(bitdepth,'int16');
    bytes_per_point=2;
else
    bytes_per_point=4;
end

%preallocate complex array
display('preallocating complex array');
 %8 May 2017, BJA
if double_down
    lil_dummy = zeros([1,1],'double');
else
    lil_dummy = zeros([1,1],'single');
end

lil_dummy =complex(lil_dummy,lil_dummy);
data_buffer=zeros((npoints/2)*ntraces,max_blocks,'like',lil_dummy);
   

%fseek to the right place, skip 60 byte header and 28 byte block header, then data
byteskip=60+max_blocks*npoints*ntraces*bytes_per_point*(cyclenum-1)+28*(cyclenum-1)*(max_blocks);
fseek(fid,byteskip,'bof');

display('reading blocks');
inx=1;%index pointer
for b = 1:max_blocks    
 
    if double_down
        data = fread(fid,npoints*ntraces,[bitdepth '=>double']);
    else
        data = fread(fid,npoints*ntraces,[bitdepth '=>single']);
    end
    data_buffer(:,inx)=complex(data(1:2:end),data(2:2:end));

    fseek(fid,28,'cof'); %skip block header
    inx=inx+1;
end  % done reading one block 
fclose(fid);

if numel(data_buffer) == prod(voldims)
    %%%% WHY WHY WHY WHY !!!!! THIS CAUSES SEPARATE CODE PATHS AND MAKES
    %%%% THE CODE FAIL!
    data_buffer = reshape(data_buffer,voldims); %reshape into 3d array
else
    if only_non_zeros
        %img = zeros([voldims(1) ntraces],'like',data_buffer);
        %img= reshape(data_buffer,[voldims(1) ntraces]);
        data_buffer = reshape(data_buffer,[voldims(1) ntraces]);
    else
        mypath = fileparts(fidpath);
        procparpath = dir([mypath '/*procpar*']);
        procparpath = fullfile(mypath,procparpath.name);
        if (~exist(procparpath,'file') || (exist(procparpath,'file')==7))
            procparpath = dir([mypath '/CS*']);
            procparpath = fullfile(mypath,procparpath.name);
        end
        % Only in this case do we need seperate variables for data_buffer
        % and img
        skiptable = skipint2skiptable(procparpath);
        img = zeros([voldims(1) prod(voldims(2:3))],'like',data_buffer);
        %img=spalloc(voldims(1),prod(voldims(2:3)),(sum(skiptable(:))*voldims(1)));
        img(:,skiptable(:)) = reshape(data_buffer,[voldims(1) ntraces]);
        data_buffer = reshape(img,voldims);  % Not memory efficient, but backwards compatible.
        %data_buffer = reshape(full(img),voldims);
    end
end

end