%% setup to new code
if ~reg_match(CS_version,'CS_v3')
    setenv('CS_CODE_DEV','latest');
    pipeline_utilities_startup=0;
    run startup;
end
%% input parameters
% to get a copy of Kspace which has been eddy current corrected, 
% load the original kspace and save as a "complex" nifti image
% 
% after that will use ecc transforms from co_reg pipeline with ants apply
% transform to get complex image space post-correction, then load back into
% matlab and ifft
% 
% finally extract slice as done with pre-corrections.


runno='N58204';
scanner_name='heike';
fid_a_name=sprintf('%s_fid',runno);
fid_dir=sprintf('d:/UserData/jjc29/scratch/%s',fid_a_name);
fid_headfile=fullfile(fid_dir,sprintf('%s.headfile',fid_a_name));
fid_file=fullfile(fid_dir,'fid');

cs_table_file=dirrec(fid_dir,'CS*');
assert(numel(cs_table_file)==1,'failed to get cs mask');
cs_table_file=cs_table_file{1};
cs_table=load_cs_table(cs_table_file);

the_scanner=scanner(scanner_name);
[h,sh]=load_acq_hdr(the_scanner,fid_file);
echos=1;
n_volumes=h.rays_acquired_in_total/h.rays_per_block;
dims.x=1134;
dims.y=992;
dims.z=992;
voxel_size=0.015;
voxel_size=[voxel_size, voxel_size, voxel_size];

%% fake out co_reg to get started
% anticipate mounting "X" from pwp-civm-ctx0[13]/s/
% doesnt work --  setenv('BIGGUS_DISKUS','X:/');
run_m0=sprintf('%s_m000',runno);
run_m1=sprintf('%s_m001',runno);
biggus_l='/y/.jamesdirtyscratchspace';
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
    if ~exist(co_reg.inputs{is},'dir')
        [s,sout]=system(co_reg.cmd{is},'-echo');
        %mkdir(co_reg.inputs);
    end
    co_reg.input_headfile{is}=fullfile(co_reg.inputs{is},sprintf('%s.headfile',run_m0));
    if ~exist(co_reg.input_headfile{is},'file')
        [s,sout]=system(sprintf('bash -l -c "dumpHeader %s %s"',scanner_name,fid_dir),'-echo');
        S_hf=read_headfile(fullfile(fid_dir,sprintf('%s.headfile',the_scanner.vendor)));
        f_a_hf=read_headfile(fid_headfile);
        co_reg.input_hf{is}=combine_struct(S_hf,f_a_hf);
        write_headfile(co_reg.input_headfile{is},co_reg.input_hf{is})
    end
end
%% define data positions to extract
%{
% not used for this.
pos.cb=253;
pos.hc=463;
pos.ac=696;
selections=fieldnames(pos);
%}

%% save vol nii's 
lil_dummy=single(complex(1,1));
process_precision = 'single'; % inside cs_recon this is double
only_non_zeros = 1;
%n_volumes=2;
vols=cell(1,n_volumes);
for vn=1:n_volumes
    %% Load n save complex nii
    mn=vn-1;
    fprintf("v_%i ",mn);
    name=sprintf('%s_m%03i',runno,mn);
    vols{vn}=name;
    for is=1:numel(suffix)
        out{is}=fullfile(co_reg.inputs{is},sprintf('%s.nii',name));
    end
    if exist(out{1},'file') && exist(out{2},'file')
        fprintf('done\n');
        % continue;
    else
        %vol_fid=load_fid_modular(fid_file,vn);
        %vol_fid=load_fid_data(fid_file,sprintf('block_number=%i',vn));
        vol_fid = load_fidCS(fid_file, ...
            1, ...
            h.rays_per_block/echos, ...
            dims.x*2, h.data_type, ...
            vn, ...
            [dims.x,dims.y,dims.z],   only_non_zeros, process_precision  );
        vol_fid = reshape(vol_fid,[dims.x,h.rays_per_block]);
        fprintf('fft x');
        vol_fid = fftshift(ifft(fftshift(vol_fid,1),[],1),1); % take ifft in the fully sampled dimension
        fprintf('insert ');
        temp_data=zeros([dims.x, dims.y, dims.z],'like',lil_dummy);
        temp_data(:,cs_table(:))=vol_fid(:,:);
        fprintf('fft yz ')
        temp_data=fftshift(fftshift(ifft(ifft(fftshift(fftshift(temp_data,2),3),[],2),[],3),2),3);
        fprintf('write\n');
        %out=fullfile('D:\UserData\jjc29\scratch\CIVM_bart_test_data',name);
        %writecfl(out,temp_data);
        for is=1:numel(suffix)
            if ~exist(out{is},'file')
                fprintf('%s ',suffix{is});
                nii=make_nii(d_func{is}(temp_data),voxel_size,size(temp_data)/2);
                save_nii(nii,out{is});
            end
        end
        fprintf('done\n');
    end
end
%% run co_reg to generate the reg images
for is=1:numel(suffix)
    co_reg.cmd{is}=sprintf('bash -l -c "declare -x BIGGUS_DISKUS=%s;co_reg --suffix=%s %s"',biggus_l,suffix{is},strjoin(vols,' '));
end
cmds=co_reg.cmd;
s=cell(size(cmds));
sout=cell(size(cmds));
parfor is=1:numel(suffix)
    [ps,psout]=system(cmds{is},'-echo');
    s{is}=ps;
    sout{is}=psout
end
%% reload complex parts to a complex
n=463;
spread=5;
d=cell(1,spread);
h=cell(1,spread);
i=0;
slice_idx=round(n-0.5*spread):round(n+0.5*spread);
for n=slice_idx
    i=i+1;
    slice_ri=cell(1,2);
    for is=1:numel(suffix)
        slice_file=sprintf('y:/.jamesdirtyscratchspace/co_reg_N58204_m000%s-work/hc/%s_%i_m000.nhdr',suffix{is},suffix{is},n);
        [slice_ri{is},hdr]=nrrdread(slice_file);
    end
    %[h,d]=read_civm_image(test)
    d{i}=complex(slice_ri{1},slice_ri{2});
    h{i}=hdr;
end
%% move back to kspace
sel=zeros([spread,size(d{1})],'like',d{1});
for s=1:numel(d)
    sel(s,:,:)=d{s};
    temp_data=d{s};
    temp_data=fftshift(fftshift(fft(fft(fftshift(fftshift(temp_data,1),2),[],1),[],2),1),2);
    sel(s,:,:)=temp_data;
end
