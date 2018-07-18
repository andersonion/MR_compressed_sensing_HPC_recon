function CS_allocate_temp_file(original_dims,recon_dims,logbits,work_subfolder,volume_runno,temp_file)
log_mode=logbits.log_mode;
log_file=logbits.log_file;
% last three inputs probably better as a varrgin with either 1 or 2 pieces.
% 
if ~exist('temp_file','var')
    temp_file = [work_subfolder '/' volume_runno '.tmp'];
end
%% Create temporary volume for intermediate work
header_size = (original_dims(1))*2; % Header data should be uint16, with the very first value telling how long the rest of the header is.
header_length = uint16(original_dims(1));
header_byte_size = (2 + header_size);
data_byte_size =  8*2*recon_dims(2)*recon_dims(3)*recon_dims(1); % 8 [bytes for double], factor of 2 for complex
file_size = header_byte_size+data_byte_size;
work_done=zeros([header_length 1]);
if ~exist(temp_file,'file')
    tic
    master_host='civmcluster1';
    host=getenv('HOSTNAME');
    host_str = '';
    if ~strcmp(master_host,host)
        host_str = ['ssh ' master_host];
    end
    fallocate_cmd = sprintf('%s fallocate -l %i %s',host_str,file_size,temp_file);
    [status,~]=system(fallocate_cmd);
    pause(2); % We seem to be having problems with dir not seeing the temp_file.
    fmeta=dir(temp_file);
    if isempty(fmeta)
        m_file_size = 0;
    else
        m_file_size = fmeta.bytes;
    end
    if status || (m_file_size ~= file_size)
        fprintf(1,'AAAAAAHHHHH!!! fallocate command failed!  Using dd command instead to initialize .tmp file');
        preallocate=sprintf('dd if=/dev/zero of=%s count=1 bs=1 seek=%i',temp_file,file_size-1);
        system(preallocate)
    end
    fid=fopen(temp_file,'r+');
    fwrite(fid,header_length,'uint16');
    fwrite(fid,work_done(:),'uint16');
    fclose(fid);
    
    chmod_temp_cmd = ['chmod 664 ' temp_file];
    system(chmod_temp_cmd);
    time_to_make_tmp_file = toc;
    log_msg =sprintf('Volume %s: .tmp file created in %0.2f seconds.\n',volume_runno,time_to_make_tmp_file);
    yet_another_logger(log_msg,log_mode,log_file);
end
end