function [data_mode, fid_path, fid_path_remote, fid_path_inprogress] = ...
    get_data_mode(the_scanner,workdir,varargin)
% function [data_mode, fid_path_struct] = GET_DATA_MODE(the_scanner,workdir,scanner_fid)
% returns data_mode, a string of local, static, or streaming,
% also gives a structof the different paths back, local, remote,
% inprogress, and current which is which is a copy of one of
% local|remote|inprogress.
% 
% Can call with more than 3 args to get string returns instead of struct
% ex [data_mode,fid_path_current,fid_path_remote,fid_path_inprogress]= GET_DATA_MODE(the_scanner,workdir,scanner_patient,scanner_fid)

% unpack multi-input
if iscell(varargin{1}) && numel(varargin)==1
    varargin=varargin{1};
end

if numel(varargin)>1
    % i dont think we should have more than one, but if we do, vomit like
    % crazy?
    % 
    % WAIT A MINUTE, what if we took the "whole list" of things?... 
    % Maybe thats the cleanest way to do stuff?
%    error('I DON''T KNOW WHAT I''M DOING');
end

% ugh, so hard to decide how to sort this out. if multi-element local file
% and remote file should be the first file so fid_consistency is easy.
% But for remote size check, we should use last so it'll properly report 0
% when not done yet.
fid_path.local=the_scanner.fid_file_local(workdir,varargin{1});
if exist(fid_path.local,'file')
    data_mode='local';
    fid_path.current=fid_path.local;
    f_info=dir(fid_path.local);
    fid_path.size=f_info.bytes;
else
    % check last remote file?
    fid_path.remote=the_scanner.fid_file_remote(varargin{1});
    remote_size=the_scanner.get_remote_filesize(varargin{end});
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
