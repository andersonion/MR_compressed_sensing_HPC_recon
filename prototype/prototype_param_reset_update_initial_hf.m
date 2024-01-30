%%
% when we need to reset param files we have to run this script.
% this is phase2 of a reset.

% this will find (all) the initial hf written and update it with the user param values.

WKS_HOME=getenv('WKS_HOME');
BD=getenv('BIGGUS_DISKUS');

%runno='N60822';n=66;rpat='%s_m%02i';
%runno='N60823';n=3;rpat='%s_m%01i';
%runno='N60825';n=3;rpat='%s_m%01i';
runno_work=fullfile(BD,[runno '.work']);
hf_a=fullfile(WKS_HOME,'recon_archive_params',[runno '.param']);
params=read_headfile(hf_a,1);
a_params=combine_struct(struct,params,'U_');
for mnum=0:n
  r=sprintf(rpat,runno,mnum);
  r_work=fullfile(runno_work,r);
  r_images=fullfile(r_work,[r 'images']);
  r_hf=fullfile(r_images,[r '.headfile']);
  r_bak=fullfile(r_work,[r '.bak']);
  r_p=fullfile(r_work,[r '.hf_noarch']);
  % If no r_bak move r_hf to r_bak
  if ~exist(r_bak,'file')
    fprintf('no file %s\n',r_bak);
    cmd=sprintf('mv %s %s',r_hf,r_bak);
    [s,sout]=system(cmd);
    assert(s==0,'failed to preserve with err %s',sout);
  end
  % edit r_bak, preserve last as r_p
  if ~exist(r_p,'file')
    fprintf('Patching %s\n',r);
    hf_b=read_headfile(r_bak);
    % combine_struct
    hf_b=combine_struct(hf_b,a_params);
% write_headfile
    cmd=sprintf('mv %s %s',r_bak,r_p);
    [s,sout]=system(cmd);
    assert(s==0,'failed to preserve with err %s',sout);
    write_headfile(r_bak,hf_b,'',0);
  else
    fprintf('previously patched %s\n',r);
  end
end
