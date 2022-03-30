function [data_mode, fid_path, fid_path_remote, fid_path_inprogress] = ...
    get_data_mode(the_scanner,workdir,varargin)
% function [data_mode, fid_path_struct] = GET_DATA_MODE(the_scanner,workdir,scanner_patient,scanner_acquisition)
% returns data_mode, a string of local, static, or streaming,
% also gives a structof the different paths back, local, remote,
% inprogress, and current which is which is a copy of one of
% local|remote|inprogress.
% 
% Can call with more than 3 args to get string returns instead of struct
% ex [data_mode,fid_path_current,fid_path_remote,fid_path_inprogress]= GET_DATA_MODE(the_scanner,workdir,scanner_patient,scanner_acquisition)

fid_path.local=the_scanner.fid_file_local(workdir,varargin{:});
if exist(fid_path.local,'file')
    data_mode='local';
    fid_path.current=fid_path.local;
    f_info=dir(fid_path.local);
    fid_path.size=f_info.bytes;
else
    fid_path.remote=the_scanner.fid_file_remote(varargin{:});
    remote_size=the_scanner.get_remote_filesize(fid_path.remote);
    if remote_size~=0
        data_mode='remote';
        fid_path.current=fid_path.remote;
        fid_path.size=remote_size;
    else
        data_mode='streaming';
        fid_path.inprogress=the_scanner.fid_file_inprogress();
        fid_path.current=fid_path.inprogress;
    end
end
if nargout>=3
    if ~isfield(fid_path,'remote')
        fid_path.remote=fid_path.current;
    end
    if ~isfield(fid_path,'inprogress')
        fid_path.remote=fid_path.current;    
    end
    fid_path_remote=fid_path.remote;
    fid_path_inprogress=fid_path.inprogress;
    fid_path=fid_path.current;
end
