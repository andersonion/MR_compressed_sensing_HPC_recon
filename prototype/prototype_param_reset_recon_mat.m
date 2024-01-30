
% when we need to reset param files we have to run this script.
% this is phase1 of a reset.

% this script adds the archive params to the recon.mat

WKS_HOME=getenv('WKS_HOME');
BD=getenv('BIGGUS_DISKUS');
%runno='N60822';n=66;rpat='%s_m%02i';
%runno='N60823';n=3;rpat='%s_m%01i';
%runno='N60825';n=3;rpat='%s_m%01i';
runno_work=fullfile(BD,[runno '.work']);
hf_a=fullfile(WKS_HOME,'recon_archive_params',[runno '.param']);

recon_file = fullfile(runno_work,[runno '_recon.mat']);
recon_mat = matfile(recon_file,'Writable',logical(1));
headfile=recon_mat.headfile;
if ~isfield(headfile,'U_code')
  fprintf('needs repair %s\nwill continue in 4 seconds (Press Ctrl + C to abort)\n',runno);
  pause(4);
  gui_info=read_headfile(hf_a,1);
  gui_info=rmfield(gui_info,'comment');
  headfile=combine_struct(headfile,gui_info,'U_');
  recon_mat.headfile=headfile;
end
