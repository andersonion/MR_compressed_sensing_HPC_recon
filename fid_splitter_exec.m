function fid_splitter_exec(local_fid,variables_file )
% For GRE/mGRE CS scans, will carve up fid into one fid for each independent
% volume.
%
% Written by BJ Anderson, CIVM
% 19 September 2017 (but really, 26 October 2017)

load(variables_file);
log_mode=1;
% Check for output fids
work_to_do = ones(length(nechoes));
for nn = 1:nechoes
    vol_string =sprintf(['%0' num2str(numel(num2str(nechoes-1))) 'i' ],nn-1);
    volume_runno = sprintf('%s_m%s',runno,vol_string);
    c_work_dir = sprintf('%s/%s/work/',study_workdir,volume_runno);
    c_fid = sprintf('%s%s.fid',c_work_dir,volume_runno);
    if exist(c_fid,'file')
        work_to_do = 0;
    end
end

% I <3 this variable construct.
if sum(work_to_do) > 0
    [input_fid, local_or_streaming_or_static]=find_input_fidCS(scanner,runno,study,agilent_series);
    datapath=['/home/mrraw/' study '/' agilent_series '.fid'];
    if ~exist(local_fid,'file')
        mode = 3;
        puller_glusterspaceCS_2(runno,datapath,scanner,study_workdir,mode);
    end
    tic
    
    try
        fid = fopen(local_fid,'r','ieee-be');
    catch ME
        disp(ME)
    end
    
    
    hdr_60byte = fread(fid,30,'int16'); % header
    
  
    if strcmp(bitdepth,'int16');
       %data= fread(fid,npoints*ntraces, 'int16');% full_fid
       bytes_per_point = 2;
    else
       %data = fread(fid,npoints*ntraces,'int32') ; % full_fid
       bytes_per_point = 4;
    end
  
    
    data= fread(fid,bytes_per_point*npoints*ntraces, '*uint8');
    
    fclose(fid);
    
    %data = reshape(data,[npoints nechoes ntraces/nechoes]);
    data = reshape(data,[npoints*bytes_per_point nechoes ntraces/nechoes]);
    data = permute(data,[1 3 2]);
    fid_load_time = toc;
    
    log_msg =sprintf('Runno %s: fid loaded and reshaped successfully in %0.2f seconds.\n',runno,fid_load_time);
    yet_another_logger(log_msg,log_mode,log_file);
    
    for nn = 1:nechoes
        tic
        vol_string =sprintf(['%0' num2str(numel(num2str(nechoes-1))) 'i' ],nn-1);
        volume_runno = sprintf('%s_m%s',runno,vol_string);
        c_work_dir = sprintf('%s/%s/work/',study_workdir,volume_runno);
        system(['mkdir -p -m 775 ' c_work_dir ]);
        
        c_hdr = hdr_60byte;
        c_hdr(19) = nn;
        c_fid = sprintf('%s%s.fid',c_work_dir,volume_runno);
        fid =fopen(c_fid,'w');
        fwrite(fid,c_hdr,'int16');
        c_data = data(:,:,nn);
        
        %{
        if strcmp(bitdepth,'int16');
            fwrite(fid,c_data(:),'int16');
        else
            fwrite(fid,c_data(:),'int32');
        end
        %}
        fwrite(fid,c_data(:),'uint8');
        
        fid_load_time = toc;
        log_msg =sprintf('Volume %s: fid loaded and reshaped successfully in %0.2f seconds.\n',volume_runno,fid_load_time);
        yet_another_logger(log_msg,log_mode,log_file);
        
    end
    
end

if exist(local_fid, 'file')
    system(['rm ' local_fid]);
end
end

