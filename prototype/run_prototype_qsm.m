% run prototype_qsm
%% prepare list of data setups to run.
data_setup={};
project='24.mst.01';
%{
mask_threshold=2;
mask_file='/home/james/Scratch/24.mst.01/240812-2-1/S69882/S69882_m0_mask.nii';
for n=82:86
    choice={project,sprintf('S698%ic',n),mask_threshold,mask_file};
    data_setup=[data_setup,{choice}];
end

mask_threshold=2;
mask_file='/home/james/Scratch/24.mst.01/230703-1-1/S69875/S69875_m0_mask.nii';
for n=75:80
    choice={project,sprintf('S698%ic',n),mask_threshold,mask_file};
    data_setup=[data_setup,{choice}];
end
mask_threshold=26000;
mask_file='/home/james/Scratch/24.mst.01/240812-1-1/S69888/S69888_m0_mask.nii';
for n=[94,88:91,94]
    choice={project,sprintf('S698%ic',n),mask_threshold,mask_file};
    data_setup=[data_setup,{choice}];
end
%}
mask_threshold=2;
n=69903;
% generated masks for each echo, and selected this one as being good enough
% for our testing.
mask_file='/home/james/Scratch/24.mst.01.work/240812-3-1/S69903c_mask/S69903c_m2_mask.nhdr';
choice={project,sprintf('S%ic',n),mask_threshold,mask_file};
data_setup=[data_setup,{choice}];

for choice=data_setup(:)'
    clear project runno_base mask_threshold mask_file;
    [project,runno_base,mask_threshold,mask_file]=choice{1}{:};

    %% resolve volume runnos to list file
    BD=getenv('BIGGUS_DISKUS');
    list_file=fullfile(BD,[runno_base '.list']);
    [s,sout]=system(sprintf('civm_input_decode --list %s -D0 %s --project %s',list_file,runno_base,project));
    assert(s==0,'error finding runnos "%s"',sout);
    %% load list file
    fid=fopen(list_file,'r');
    assert(fid>0,'Failed to open file %s',list_file);
    C=textscan(fid,'%s');fclose(fid);
    runnos=C{1};clear C fid;
    %% find volume directories
    echo_dirs=cell(size(runnos));
    for idx=1:numel(runnos)
        runno=runnos{idx};
        [s,sout]=system(sprintf('civm_runno_path %s %s/*',runno,project));
        assert(s==0,'error getting runno path, output was "%s"',sout);
        echo_dirs{idx}=sout;
    end

    %% get spec and filename save version
    [~,e1meta]=read_civm_image(echo_dirs{1});
    specid=e1meta.U_specid;
    fn_spec=regexprep(specid,'[:-_;]','-','all');

    %% generate per-echo masks.
    % nhdr mode
    % set empty to use prescribed mask above.
    use_multi_mask='-mm';
    % In testing, this appeard to give a worse result.
    use_multi_mask='';
    if ~isempty(use_multi_mask) || ~exist(mask_file,'file')
        multi_mask=cell(size(echo_dirs));
        debug=0;
        wrk_name=sprintf('%s_mask',runno_base);
        work_dir=fullfile(BD,[project '.work'],fn_spec,wrk_name);
        if ~exist(work_dir,'dir')
            mkdir(work_dir);
        end
        for e=1:numel(echo_dirs)
            echod=echo_dirs{e};
            [~,runno,~]=fileparts(echod);
            echo_nhdr=fullfile(work_dir,[runno '.nhdr']);
            % mk_nhdr input is headfiles :p
            echo_hf=fullfile(echod,[runno '.headfile']);
            assert(exist(echo_hf,'file'),'Didnt find headfile for mk_nhdr');
            [s,sout]=system(sprintf('mk_nhdr -w %s %s -o %s',work_dir,echo_hf,echo_nhdr));
            assert(s==0,'error running mk_nhdr %s',sout);
            out_mask=fullfile(work_dir,[runno '_mask.nhdr']);
            strip_mask_exec(echo_nhdr,1,mask_threshold,out_mask,[],[],debug,0);
            multi_mask{e}=out_mask;
        end
        if ~exist(mask_file,'file')
            mask_file=multi_mask{1};
        end
    end
    %% qsm for all echo combos.
    out_dir=fullfile(BD,project,fn_spec,runno_base,'QSM_star');
    if ~exist(out_dir,'dir')
        mkdir(out_dir);
    end
    nechos=numel(echo_dirs);
    sel=0:(nechos-1);
    for e_used=nechos:-1:1
        e_to_use=nchoosek(sel,e_used);
        for s_idx=1:height(e_to_use)
            echo_set=e_to_use(s_idx,:);
            fe=echo_set(1);
            le=echo_set(end);
            t=fe:le;
            if ~all(size(t)==size(echo_set)) || ~all(t==echo_set)
                continue;
            end
            if fe ~= le
                wrk_name=sprintf('%s_e%i-%i_qsm%s',runno_base,fe,le,use_multi_mask);
            else
                wrk_name=sprintf('%s_m%i_qsm%s',runno_base,fe,use_multi_mask);
            end
            work_dir=fullfile(BD,[project '.work'],fn_spec,wrk_name);
            out_qsm=fullfile(out_dir,[wrk_name '.nii.gz']);
            fprintf('%s\n',work_dir);
            if isempty(use_multi_mask)
                prototype_starqsm(echo_dirs(echo_set+1),work_dir,out_qsm,mask_file);
            else
                prototype_starqsm(echo_dirs(echo_set+1),work_dir,out_qsm,multi_mask(echo_set+1));
            end
        end
    end
end
