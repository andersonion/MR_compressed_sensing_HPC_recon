function fid_splitter_exec(local_fid,variables_file )
% For GRE/mGRE CS scans, will carve up fid into one fid for each independent
% volume.
%
% Written by BJ Anderson, CIVM
% 19 September 2017 (but really, 26 October 2017)

% for all execs run this little bit of code which prints start and stop time using magic.
C___=exec_startup();
% load(variables_file);
recon_mat=matfile(variables_file);
log_mode=1;
% Check for output fids
%work_to_do = ones(length(recon_mat.nechoes));
work_to_do = ones(1,recon_mat.nechoes);
for nn = 1:recon_mat.nechoes
    vol_string =sprintf(['%0' num2str(numel(num2str(recon_mat.nechoes-1))) 'i' ],nn-1);
    volume_runno = sprintf('%s_m%s',recon_mat.runno,vol_string);
    c_work_dir = sprintf('%s/%s/work/',recon_mat.agilent_study_workdir,volume_runno);
    c_fid = sprintf('%s%s.fid',c_work_dir,volume_runno);
    if exist(c_fid,'file')
        work_to_do(nn) = 0;
    end
end

% I <3 this variable construct.
if sum(work_to_do)
    %{
    USED TO ALSO GET DATA :P thats yucky!
    [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
    datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
    if ~exist(local_fid,'file')
        mode = 3;
        puller_glusterspaceCS_2(runno,datapath,scanner,study_workdir,mode);
    end
    %}
    tic
    
    try
        fid = fopen(local_fid,'r','ieee-be');
    catch ME
        disp(ME)
    end
    %% failed on fopen, maybe symbolic link schenanigans.
    if exist('ME','var') || fid<0 
      [s,sout]=system(sprintf('readlink %s',local_fid));
      if s==0
          sout=strtrim(sout);
          if exist(sout,'file')
              fid = fopen(sout,'r','ieee-be');
          end
      end
    end
    %%
    if exist('ME','var') || fid<0 
        close all;
        fprintf('Trouble with opening fid:%s\n',local_fid)
        quit force
    end
    
    if strcmp(recon_mat.bitdepth,'int16');
        %data= fread(fid,npoints*ntraces, 'int16');% full_fid
        bytes_per_point = 2;
    else
        %data = fread(fid,npoints*ntraces,'int32') ; % full_fid
        bytes_per_point = 4;
    end
    
    hdr_60byte = fread(fid,30,'uint16');
    %% read full file trying to be 100% data agnostic 
    % because all we want to do is transcribe the bytes from the input file into the output.
    % Suspect the trouble here is data blocks are not updated in size when
    % it comes time to read them... 
    % Fomer simple line which failed, this was not reverted becuase the new
    % lines should be just as efficient, and they'll be resilient to slow
    % disk problems.
    % [data,count]= fread(fid,read_bytes,'*uint8');
    count=0;
    % forcing doubles becuase our header vars may not be, if they're not
    % doubles we get stupid bit errors. 
    read_bytes=double(bytes_per_point) ...
        * double(recon_mat.npoints) ...
        * double(recon_mat.ntraces);
    data=zeros([read_bytes,1],'uint8');
    try_lim=10;
    while count<read_bytes && try_lim>0
        [buff,ncount]= fread(fid,read_bytes-count,'*uint8');
        if ncount==read_bytes
            data=buff;
        else
            data(count+1:count+ncount)=buff;
        end
        count=count+ncount;
        try_lim=try_lim-1;
    end; 
    fclose(fid);
    if(try_lim<9)
        warning('Took %i tries to read full data',10-try_lim);
    end
    % get rid of temp vars cluttering the workspace.
    clear count ncount buff read_bytes try_count;
    
    %data = reshape(data,[npoints recon_mat.nechoes ntraces/recon_mat.nechoes]);
    ldims=[double(bytes_per_point)*double(recon_mat.npoints) double(recon_mat.nechoes) double(recon_mat.ntraces)/double(recon_mat.nechoes)];
    if numel(data)/prod(ldims) ~=1
        error('LOADING DIMENSION ERROR!');
    end
    
    data = reshape(data,ldims);
    data = permute(data,[1 3 2]);
    fid_load_time = toc;
    
    log_msg =sprintf('Runno %s: fid loaded and reshaped successfully in %0.2f seconds.\n', recon_mat.runno,fid_load_time);
    yet_another_logger(log_msg,log_mode,recon_mat.log_file);
    
    for nn = 1:recon_mat.nechoes
        tic
        vol_string =sprintf(['%0' num2str(numel(num2str(recon_mat.nechoes-1))) 'i' ],nn-1);
        volume_runno = sprintf('%s_m%s',recon_mat.runno,vol_string);
        c_work_dir = sprintf('%s/%s/work/',recon_mat.agilent_study_workdir,volume_runno);
        if ~exist(c_work_dir,'dir')
            warning('Creating directory (%s) to save split fid, this should have been done already.',c_work_dir);
            system(['mkdir -p ' c_work_dir ]);
        end
        c_hdr = hdr_60byte;
        c_hdr(19) = nn;
        c_fid = sprintf('%s%s.fid',c_work_dir,volume_runno);
        fid =fopen(c_fid,'w','ieee-be');
        fwrite(fid,c_hdr,'uint16');
        c_data = data(:,:,nn);

        fwrite(fid,c_data(:),'uint8');
        
        fid_load_time = toc;
        log_msg =sprintf('Volume %s: fid loaded and reshaped successfully in %0.2f seconds.\n',volume_runno,fid_load_time);
        yet_another_logger(log_msg,log_mode,recon_mat.log_file);
        
    end
    
end

end

