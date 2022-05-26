function scan_data_setup = refresh_volume_index(input_data,the_scanner,study_workdir,options)
% gets the volume index file from our custom mrsolutions code.

% how many minutes old does the index have to be before we try to replace it
% This is reduce chance of collision with many things grabbing it.
min_index_age=5;
if ~exist(input_data,'file')
    % todo: time-bin this fetch command to only grab if current is older
    % than 5 minutes
    index_fetch=sprintf('puller_simple -o -f file -u %s %s %s %s',...
        options.scanner_user, the_scanner.name, path_convert_platform(input_data,'linux'), study_workdir);
else
    index_fetch=sprintf('cp -p %s %s ',  input_data, study_workdir);
end
% we (almost)always grab the index because it is how we know how much data
% will be done. It is supposed to be prepopulated with numbers on
% the scanner, and after each scan is done the data file is filled
% in
fetch_index=true;
[~,dn,de]=fileparts(input_data);
index_name=[dn,de];
local_index=fullfile(study_workdir,index_name);
e=dir(local_index);
if numel(e)
    file_age=datetime(datestr(now))-datetime(e.date);
    ts=time_struct(seconds(file_age));
    fetch_index  = min_index_age <= minutes(ts.duration());
end
if fetch_index
    [s,sout] = system(index_fetch);
    assert(s==0,sout);
end
% cleans up user input to solidly hold REMOTE file locations
scan_data_setup=the_scanner.data_definition_cleanup(input_data);
% becuase i dont want to make data_definition_cleanup complicated, we
% load volume index externally, maybe we can load it and pass it as
% input data? and that would be more reasonable?
if ~isfield(scan_data_setup,'fid') && reg_match(input_data,'volume_index.txt')
    local_index=load_index_file(local_index);
    if ~path_is_absolute(local_index.fid{1})
        % local_index.fid = cellfun(@(c) fullfile(scan_data_setup.main,c), local_index.fid)
        idx_ready = cellfun(@(c) ~isempty(c),local_index.fid);
        full_paths = cellfun(@(c) fullfile(scan_data_setup.main,c), local_index.fid, 'UniformOutput', false);
        local_index.fid(idx_ready) = full_paths(idx_ready);
    end
    scan_data_setup.fid=local_index.fid;
end

