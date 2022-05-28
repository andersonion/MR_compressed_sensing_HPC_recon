function data_headfile = save_vol_data_headfile(setup_variables,hdr)
% Using cs recon setup variables, get the fid data file, then convert fid
% header info to headfile in the volume_directory.

setup_var=matfile(setup_variables);
[~,fid_name]=fileparts(setup_var.volume_fid);
data_headfile=fullfile(setup_var.volume_dir,[fid_name,'.headfile']);

e_f=dir(setup_var.volume_fid);
e_hf=dir(data_headfile);
if numel(e_f) && numel(e_hf) && e_f.datenum <= e_hf.datenum 
    % work done and hf is newer than fid, bail.
    return;
end

recon_mat=matfile(setup_var.recon_file);
the_scanner=recon_mat.the_scanner;


%{
log_file=setup_var.volume_log_file;
log_mode=1;
options=recon_mat.options;
volume_number=setup_var.volume_number;
volume_runno=setup_var.volume_runno;
%}

if ~exist('hdr','var')
    [~,hdr]=load_acq_hdr(the_scanner,setup_var.volume_fid);
end

if strcmp(the_scanner.vendor,'mrsolutions')
    mrs2headfile(data_headfile,hdr,'mrd_');
elseif strcmp(the_scanner.vendor,'agilent')
    warning('Untested');
    write_headfile(data_headfile,hdr,'fid_');
end

end