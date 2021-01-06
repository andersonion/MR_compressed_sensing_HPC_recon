function CS_reservation_update(runno,new_reservation)
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
cd(getenv('BIGGUS_DISKUS'));
[s,p]=system(sprintf('ls -d %s.work',runno));
if s~=0
    error('failed fo find dir with %s',p);
end
p=strtrim(p);
cd(p)
base_file=sprintf('%srecon.mat',runno);


[s,setup_files]=system(sprintf('ls -d %s_m*/%s_m*setup_variables.mat',runno,runno));
if s==0
    setup_files=strtrim(setup_files);
    setup_files=strsplit(setup_files,'\n');
else
    setup_files={};
end

set_CS_reservation([base_file,setup_files],new_reservation);
s=system(sprintf('slurm_change_reservation %s',new_reservation));
if s==0
    fprintf('%s sucess\n',mfilename);
end
%{
scontrol update job $(for j in $(grep -vi Run ~/slurm_queue |grep jjc29|awk '{print $1}'|xargs); do echo -n "$j,";done) reservation=jjc29_33
%}
end



function set_CS_reservation(files,new_reservation)

for fn=1:numel(files)
    the_file=files{fn};
    mf=matfile(the_file,'Writable',true);
    if isprop(mf,'options')
        options=mf.options;
        options.CS_reservation=new_reservation;
        mf.options=options;
    end
end


end
