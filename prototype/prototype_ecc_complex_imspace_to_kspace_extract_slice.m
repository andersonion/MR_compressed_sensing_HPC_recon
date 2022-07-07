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

%% define co_reg folder struct
% anticipate mounting "s" from pwp-civm-ctx0[13]/s/
% doesnt work --  setenv('BIGGUS_DISKUS','s:/');
run_m0=sprintf('%s_m000',runno);
run_m1=sprintf('%s_m001',runno);
biggus_l='/s/.jamesdirtyscratchspace';
biggus_w=path_convert_platform(biggus_l,'win');
suffix={'real','imag'};
d_func={@real,@imag};
co_reg=struct;
for is=1:numel(suffix)
    co_reg.base{is}=fullfile(biggus_w,sprintf('co_reg_%s%s',run_m0,suffix{is}));
    co_reg.inputs{is}=sprintf('%s-inputs',co_reg.base{is});
    co_reg.work{is}=sprintf('%s-work',co_reg.base{is});
    co_reg.results{is}=sprintf('%s-results',co_reg.base{is});
    co_reg.cmd{is}=sprintf('bash -l -c "declare -x BIGGUS_DISKUS=%s;co_reg --suffix=%s %s %s"',biggus_l,suffix{is},run_m0,run_m1);
    co_reg.input_headfile{is}=fullfile(co_reg.inputs{is},sprintf('%s.headfile',run_m0));
    % while system not available cant check this.
    assert(exist(co_reg.input_headfile{is},'file')>0,'need %s, maytbe we''re being run out of order',co_reg.input_headfile{is});
end
%% load parallel into cell
lil_dummy=single(complex(1,1));
only_non_zeros = 1;
cell_bucket=cell(1,n_volumes);
% save this N of slices out centered around our selected positions. 
% Odd numbers slect same N on both sides of selected. 
% Even has 1 more before selected than after.
% used 5 in the test case, not clear we should load more than 1.
spread=5;
%n_volumes=2;% test case 2 vol
parfor vn=1:n_volumes
    mn=vn-1;
    fprintf("v_%i ",mn);
    name=sprintf('Reg_%s_m%03i.nhdr',runno,mn);
    cplx_parts=cell(1,2);
    for is=1:numel(suffix)
        % load volume
        fprintf('%s ',suffix{is})
        vol_file=fullfile(co_reg.work{is},name);
        vol_img=nrrdread(vol_file);
        % for each slice selection extract
        % will contain just the three loaded parts for this "suffix"
        %   volume(real or imag)
        slice_sel=cell(size(selections));
        for sn=1:numel(selections)
            n=selections{sn};
            fprintf("%s_%i ",n,pos.(n));
            i=0;
            slice_idx=round(pos.(n)-0.5*spread):(round(pos.(n)+0.5*spread)-1);
            c_slices=cell(1,spread);
            for slice_i=slice_idx
                i=i+1;
                c_slices{i}=vol_img(slice_i,:,:);
            end
            slice_sel{sn}=c_slices;
        end
        cplx_parts{is}=slice_sel;
    end
    %% move back to kspace
    fprintf('fft ');
    ro_pack=cell(size(selections));
    for sn=1:numel(selections)
        n=selections{sn};
        fprintf("%s ",n);
        sel=zeros([spread,dims.y,dims.z],'like',lil_dummy);
        for slice_i=1:spread
            temp_data=complex(...
                cplx_parts{1}{sn}{slice_i}, ...
                cplx_parts{2}{sn}{slice_i}  );
            temp_data=fftshift(fftshift(fft(fft(fftshift(fftshift(temp_data,2),3),[],2),[],3),2),3);
            sel(slice_i,:,:)=temp_data;
        end
        %{
        if spread>1
            error('incomplete code');
        end
        %}
        % this reduces the selected parts to one slice because the others
        % were not set-up
        %sel=squeeze(sel(1,:,:));
        sel=squeeze(sel);
        %%% THIS may be a mistake! we're eliminating points which were NOT
        %%% part of the mask. As part of the transformation, the points
        %%% could have moved in kspace.
        %ro_slice(cs_table(:))=sel(cs_table(:));
        ro_pack{sn}=sel;
    end
    fprintf(' vol done\n');
    cell_bucket{vn}=ro_pack;
end
%% extract from cell into normal data structure.
% This can probably be replaced by a one liner... later.
t_uncel=tic;
fprintf('Uncell data\n');
for vn=1:n_volumes
    for sn=1:numel(selections)
        n=selections{sn};
        data.(n)(1:spread,:,:,vn)=cell_bucket{vn}{sn};
    end
end
fprintf("Time to uncell data %s",string(time_struct(toc(t_uncel))));
%% save selected slices
% write cfl function from bart
t_write=tic;
for sn=1:numel(selections)
    n=selections{sn};
    slice_idx=round(pos.(n)-0.5*spread):(round(pos.(n)+0.5*spread)-1);
    pstr=sprintf('%i',slice_idx(1));
    if spread>1
        % stop and save the one slice only version
        name=sprintf('ecc_%s_%i',n,pos.(n));
        out=fullfile('D:\UserData\jjc29\scratch\CIVM_bart_test_data',name);
        sel_slice=slice_idx==pos.(n);
        writecfl(out,data.(n)(sel_slice,:,:,:));
        % 
        pstr=sprintf('%s-%i',pstr,slice_idx(end));
    end
    name=sprintf('ecc_%s_%s',n,pstr);
    out=fullfile('D:\UserData\jjc29\scratch\CIVM_bart_test_data',name);
    writecfl(out,data.(n))
end
fprintf("Time to write data %s",string(time_struct(toc(t_write))));
name='sample_mask';
mask_out=fullfile('D:\UserData\jjc29\scratch\CIVM_bart_test_data',name);
writecfl(mask_out,cs_table);
%{
%% test passed
test=readcfl(out);
disp_vol_center(squeeze(test(3,:,:,:)),0);

test=fftshift(fftshift(ifft(ifft(fftshift(fftshift(test,2),3),[],2),[],3),2),3);
disp_vol_center(squeeze(test),0);
%}
%% sava b0 and b1 full volume
%{
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
%}


