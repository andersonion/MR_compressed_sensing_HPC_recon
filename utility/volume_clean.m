function volume_clean(setup_variables)
% function volume_clean(volume_variable_file)
% Volume_clean for csrecon, removes tmp files if all work is done.
% All relevant parameters are burried inside the volume_variable file(take care!)
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

if ~isdeployed

else
    % for all execs run this little bit of code which prints start and stop time using magic.
    C___=exec_startup();
end

setup_var=matfile(setup_variables);
recon_mat=matfile(setup_var.recon_file);
options=recon_mat.options;

%% log details
if ~exist('log_mode','var')
    log_mode = 1;
end
log_files = {};
log_files{end+1}=setup_var.volume_log_file;
log_files{end+1}=recon_mat.log_file;

if (numel(log_files) > 0)
    log_file = strjoin(log_files,',');
else
    log_file = '';
    log_mode = 3;
end

if ~options.keep_work && ~options.process_headfiles_only
    % Lets adjust to keeping work until our final headfile is complete.
    % That is, its more than 20KiB big. 
    % 20 was chosen because typical procpars are 60KiB, and incomplete
    % headfiles are typicallyu 5-6KiB.
    %
    % The problem with this setup is that the cleanup will never be run!
    % When streaming procpar's are completed independent of this function,
    % and much later, so we're blind to them. 
    cleanup_ready=0;
    if exist(setup_var.headfile_path,'file')
        BytesPerKiB=2^10;
        hf_minKiB=20;
        hfinfo=dir(setup_var.headfile_path);
        if hfinfo.bytes>hf_minKiB*BytesPerKiB
            cleanup_ready=1;
        end
    end
    if cleanup_ready
        if exist(setup_var.work_subfolder,'dir')
            log_msg =sprintf('Images have been successfully reconstructed; removing %s now...',setup_var.work_subfolder);
            yet_another_logger(log_msg,log_mode,log_file);
            rm_cmd=sprintf('rm -rf %s',setup_var.work_subfolder);
            [s,sout]=system(rm_cmd);
            assert(s==0,sout);
        else
            log_msg =sprintf('Work folder %s already appears to have been removed. No action will be taken.\n',setup_var.work_subfolder);
            yet_another_logger(log_msg,log_mode,log_file);
        end
    else
        log_msg =sprintf('Images have not been successfully transferred yet; work folder will not be removed at this time.\n');
        yet_another_logger(log_msg,log_mode,log_file);
    end
end
