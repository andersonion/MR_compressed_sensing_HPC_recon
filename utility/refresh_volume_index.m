function scan_data_setup = refresh_volume_index(input_data,the_scanner,study_workdir,options)
% gets the volume index file from our custom mrsolutions code.
% how many minutes old does the index have to be before we try to replace it
% This is reduce chance of collision with many things grabbing it.
min_index_age=5;
if ~exist(input_data,'file')
    input_data=path_convert_platform(input_data,'linux');
    index_fetch=sprintf('puller_simple -o -f file -u %s %s ''%s'' ''%s''',...
        options.scanner_user, the_scanner.name, input_data, path_convert_platform(study_workdir,'lin'));
else
    index_fetch=sprintf('cp -p ''%s'' ''%s'' ',  input_data, study_workdir);
end
% we (almost)always grab the index because it is how we know how much data
% will be done. It is supposed to be prepopulated with numbers on
% the scanner, and after each scan is done the data file is filled
% in
fetch_index=true;
[~,dn,de]=fileparts(input_data);
index_name=[dn,de];
index_file=fullfile(study_workdir,index_name);
e=dir(index_file);
if numel(e)
    file_age=datetime(datestr(now))-datetime(e.date);
    ts=time_struct(seconds(file_age));
    fetch_index  = min_index_age <= minutes(ts.duration());
end

% cleans up user input to solidly hold REMOTE file locations
scan_data_setup=the_scanner.data_definition_cleanup(input_data);
if ~isfield(scan_data_setup,'fid') ...
        && reg_match(input_data,'volume_index.txt') ...
        && exist(index_file,'file')
    % If we didnt find the fid yet, and are the special volume_index.txt
    % case, load it to see if its complete.
    fid_index=load_index_file(index_file,scan_data_setup.main);
    if sum(cellfun(@isempty,fid_index.fid))==0
        % if there are no empty entries, shut off fetch_index because even
        % if its old, it should be done.
        fetch_index=0;
    end
end
if fetch_index
    [s,sout] = system(index_fetch);
    if s~=0
      warning(sout);
      scan_data_setup=[];
      return;
%{
        if ~exist('file_age','var') ||  1.5 < days(file_age)
            assert(s==0,sout);
        else
            warning(sout);
        end
%}
    end
end

% becuase i dont want to make data_definition_cleanup complicated, we
% load volume index externally, maybe we can load it and pass it as
% input data? and that would be more reasonable?
if ~isfield(scan_data_setup,'fid') ...
        && reg_match(input_data,'volume_index.txt') ...
        && exist(index_file,'file')
    if fetch_index
        fid_index=load_index_file(index_file,scan_data_setup.main);
    end
    scan_data_setup.fid=fid_index.fid;
end

