function recon_report_progress(base_runno,data_directory)
% function recon_report_progress(rx,bd)
% function to report total progress of a cs recon. 

if ~exist('base_runno','var')
    error('must supply runno');
end
if ~exist('data_directory','var')
    data_directory=getenv('BIGGUS_DISKUS');
end

[s,ls_blob]=system(sprintf('ls -d %s/%s.work/%s*/',data_directory,base_runno,base_runno)); % the */ forces a trailing slash.
if s==0 % unix status check
    ls_blob=strtrim(ls_blob);
    C=strsplit(ls_blob);
    [dummy, index] = sort(C);
    rundirs = C(index);clear C dummy index;
    sum=0;
    for ri=1:numel(rundirs)
        if isempty(rundirs{ri})
           continue;
        end
        vd=rundirs{ri}(1:end-1);
        [~,vr]=fileparts(vd);
        [sp,lm,pc]=check_status_of_CSrecon(vd,vr);
        fprintf('%05.2f%% - %s',pc,lm);
        sum=sum+pc;
    end
    total_completion=sum/(numel(rundirs));
    fprintf('TOTAL progress: %05.2f%%\n',total_completion);
else
    error('didnt find runno %s in working folder %s.',base_runno,data_directory);
end
