% To facilitate external help improving reconstruction we want to extract a
% slice of a large dataset.

% This will load a fid, insert into proper mask position, then save the
% complex data.

runno='N58204';
fid_dir=sprintf('d:/UserData/jjc29/scratch/%s_fid',runno);
fid_file=fullfile(fid_dir,'fid');
cs_table_file=dirrec(fid_dir,'CS*');
assert(numel(cs_table_file)==1,'failed to get cs mask');
cs_table_file=cs_table_file{1};
cs_table=load_cs_table(cs_table_file);

the_scanner=scanner('heike');
[h,sh]=load_acq_hdr(the_scanner,fid_file);
echos=1;
n_volumes=h.rays_acquired_in_total/h.rays_per_block;
dims.x=1134;
dims.y=992;
dims.z=992;

%% define data positions to extract
pos.cb=253;
pos.hc=463;
pos.ac=696;
selections=fieldnames(pos);

%% allocate
% no, lets make a "3d" stack for each slice selection.
lil_dummy=single(complex(1,1));
ro_slice=zeros([dims.y,dims.z],'like',lil_dummy);
for sn=1:numel(selections)
    n=selections{sn};
    data.(n)=zeros([1,dims.y,dims.z,n_volumes],'like',lil_dummy);
end

%% load parallel into cell
%b0_fid=load_fid_modular(fid_file,1);
%b1_fid=load_fid_modular(fid_file,2);
process_precision = 'single'; % inside cs_recon this is double
only_non_zeros = 1;
cell_bucket=cell(1,n_volumes);
parfor vn=1:n_volumes
    fprintf("v_%i ",vn);
    %vol_fid=load_fid_modular(fid_file,vn);
    %vol_fid=load_fid_data(fid_file,sprintf('block_number=%i',vn));
    vol_fid = load_fidCS(fid_file, ...
        1, ...
        h.rays_per_block/echos, ...
        dims.x*2, h.data_type, ...
        vn, ...
        [dims.x,dims.y,dims.z],   only_non_zeros, process_precision  );
   
    %% ifft on readout
    vol_fid = reshape(vol_fid,[dims.x,h.rays_per_block]);
    fprintf('fft ');
    vol_fid = fftshift(ifft(fftshift(vol_fid,1),[],1),1); % take ifft in the fully sampled dimension
    % temp_data=zeros([dims.x, dims.y, dims.z],'like',lil_dummy);
    % temp_data(:,cs_table(:))=vol_fid(:,:);
    % temp_data=fftshift(fftshift(ifft(ifft(fftshift(fftshift(temp_data,2),3),[],2),[],3),2),3);
    ro_pack=cell(size(selections));
    for sn=1:numel(selections)
        n=selections{sn};
        fprintf("%s_%i ",n,pos.(n));
        s_data=vol_fid(pos.(n),:,:);
        ro_slice=zeros([dims.y,dims.z],'like',lil_dummy);
        ro_slice(cs_table(:))=s_data(:);
        ro_pack{sn}=ro_slice;
    end
    cell_bucket{vn}=ro_pack;
end
%% extract from cell into normal data structure.
% This can probably be replaced by a one liner... later.
t_uncel=tic;
for vn=1:n_volumes
    for sn=1:numel(selections)
        n=selections{sn};
        data.(n)(1,:,:,vn)=cell_bucket{vn}{sn};
    end
end
fprintf("Time to uncell data %s",string(time_struct(toc(t_uncel))));
%% save selected slices
% write cfl function from bart
for sn=1:numel(selections)
    n=selections{sn};
    name=sprintf('%s_%i',n,pos.(n));
    out=fullfile('D:\UserData\jjc29\scratch\CIVM_bart_test_data',name);
    writecfl(out,data.(n))
end
%{
%% test passed
test=readcfl(out);
disp_vol_center(squeeze(test),0);
%}
%% sava b0 and b1 full volume
for vn=1:2
    mn=vn-1;
    fprintf("v_%i ",mn);
    %vol_fid=load_fid_modular(fid_file,vn);
    %vol_fid=load_fid_data(fid_file,sprintf('block_number=%i',vn));
    vol_fid = load_fidCS(fid_file, ...
        1, ...
        h.rays_per_block/echos, ...
        dims.x*2, h.data_type, ...
        vn, ...
        [dims.x,dims.y,dims.z],   only_non_zeros, process_precision  );
    vol_fid = reshape(vol_fid,[dims.x,h.rays_per_block]);
    fprintf('fft ');
    vol_fid = fftshift(ifft(fftshift(vol_fid,1),[],1),1); % take ifft in the fully sampled dimension
    fprintf('insert ');
    temp_data=zeros([dims.x, dims.y, dims.z],'like',lil_dummy);
    temp_data(:,cs_table(:))=vol_fid(:,:);
    fprintf('write\n');
    name=sprintf('%s_m%03i',runno,mn);
    out=fullfile('D:\UserData\jjc29\scratch\CIVM_bart_test_data',name);
    writecfl(out,temp_data);
end
