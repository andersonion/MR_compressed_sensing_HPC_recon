function [data_mode, fid_path] = get_data_mode(the_scanner,workdir,agilent_study,agilent_series)
% reports if we're in local, static, or streaming mode, also gives a struct
% of the different paths back.
% not convinced i need the paths back... 

fid_path.local=the_scanner.fid_file_local(workdir,agilent_study,agilent_series);
if exist(fid_path.local,'file')
    data_mode='local';
    fid_path.current=fid_path.local;
else
    fid_path.remote=the_scanner.fid_file_remote(agilent_study,agilent_series);
    remote_size=the_scanner.get_remote_filesize(fid_path.remote);
    if remote_size~=0
        data_mode='remote';
        fid_path.current=fid_path.remote;
    else
        data_mode='streaming';
        fid_path.inprogress=the_scanner.fid_file_inprogress();
        fid_path.current=fid_path.inprogress;
    end
end
fid_path.current=fid_path.current;
