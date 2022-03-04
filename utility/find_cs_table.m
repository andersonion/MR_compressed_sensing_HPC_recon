function [full_CS_table_path,target_folder]=find_cs_table(procpar)

% A procpar file should end in 'procpar' ( or be only procpar :D )
if ~exist(procpar,'file')
    error('Unable to find specified procpar file %s.', procpar);
end
pp = readprocparCS(procpar);
if ~isfield(pp,'petableCS')
    e_string1='Cannot find field ''petableCS'' containing the path to the CStable in procpar file ''';
    e_string2='''; it is possible that this is not a compressed sending experiment.';
    error('%s%s%s',e_string1,procpar,e_string2);
end
% Get CStable path
full_CS_table_path = pp.petableCS;
full_CS_table_path=full_CS_table_path{1};
target_folder = fileparts(procpar);
% Get dim_y and dim_z (dim2/dim3)
dim2 = pp.nv;
dim3 = pp.nv2;
if ~exist(table_target,'file')
    error('table not present, and i think this code shouldn''t fetch it');
    % Guess which scanner is the CStable source based on runno prefix
    [~,Tname]=fileparts(target_folder);
    if (strcmp(Tname(1),'N'))
        scanner = 'heike';
    else
        scanner = 'kamy';
    end
    % pull_table
    cmd = [ 'puller_simple  -o -f file ' scanner ' ''../../../../home/vnmr1/vnmrsys/tablib/' CS_table_name ''' ' target_folder];
    [skiptable,sout]=system(cmd); if skiptable~=0; warning(sout); end;clear cmd;
    if ~exist(table_target,'file')
        error('Unable to retrieve CS table: %s.', full_CS_table_path);
    end
    clear cmd;
end