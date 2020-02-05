function archive_string=write_archive_tag(runno,spacename, slices, projectcode, img_format, civmid, display_prompt, out_dir)
%This function creates the tag file needed for archiving
% runno = run number(s) to put in, can be cell array of runs
% spacename = biggus_diskus, or engine_work_directory 
% slices= nslices, should be same for all
% projectcode= projectcode, should be same for all
% img_format= image formatcode with period for sally bits
% civmid of the archiver
% display_prompt = boolean to display the archiveme infomration or to just
% pass it back.
%
% example
%B00663_m081,androsspace,128,10.eds.02,.raw

% this code relies on the spacename not being a real directory, this fixes
% it just in case. 
if regexp(spacename,'^/[A-Za-z0-9_-]+$')
    spacename=spacename(2:end);
end
if regexp(spacename,'^/[A-Za-z0-9_-]+/$')
    spacename=spacename(2:end-1);
end

if ~exist('display_prompt','var')
    display_prompt=true;
end

if ~exist('out_dir','var')
    out_dir=[spacename,'/Archive_Tags'];
end
    
if ~iscell(runno)
    runno={runno};
end

test=regexpi(img_format,'^(\.).*$','match');
if ~numel(test)
    img_format=[ '.' img_format ];
end

%% sort runnumbers and insert a comment between any blocks, 
% this should clear up any lingering issuses with channel mode tags. 

runbase='';
strptr=1;
runno=sort(runno);
tempbase=runno{1}(1:strptr);
startpos=1;
while strcmp(runbase,'')
    expand_flag=1;
    for i=startpos:length(runno)
        if regexp(runno{i},'^#.*')
            %&& isempty(regexp(runno{i},'^#.*', 'once'))
            fprintf('%s',runno{i});
        elseif regexp(runno{i}(1:strptr+1),[tempbase '.*' ],'once') 
            
        else
%             fprintf('insert comment before %s\n',runno{i});
            comment_insert=i;
            expand_flag=0;
            break;
        end
    end
    
    if expand_flag
%         fprintf('tempbase: %s\n',tempbase);
        tempbase=runno{startpos}(1:strptr);
        strptr=strptr+1;
    else
        % expand by one
        elements=numel(runno);
        run_bak=runno;
        runno=cell([1,elements+1]);
        runno(1:comment_insert)=run_bak(1:comment_insert);
        runno(comment_insert+1:elements+1)=run_bak(comment_insert:elements);
        % set entry to comment 
        runno(comment_insert)={'#'};
        % change starting pos.
        startpos=comment_insert(end)+1;
%         strptr=1;
        tempbase(end)=[];
        strptr=strptr-1;
    end
    if strptr==length(runno{end})
        runbase=tempbase(1:end-1);
    end
end
%% make tag cells to write. 
tag_cells=cell(length(runno),1);
for i=1:length(runno)
    tag_cells{i,1}=[runno{i} ',' spacename ',' num2str(slices) ',' projectcode ',' img_format];
    runno_file_out=sprintf('/%s/READY_%s',out_dir,runno{i}');
    if exist(runno_file_out,'file')
%         warning('deleting a file found:%s',runno_file_out);
        delete(runno_file_out);
    end
end
tag_cells{end+1, 1}=['# recon_person=' civmid];
tag_cells{end+1, 1}=['# tag_file_creator=' 'CSv2_matlab'];
% tag_file{end+1, 1}=['# Filtering_method= ' Filtering_method];
tagfile_name=['READY_' runno{1}];
dlmcell(['/' out_dir '/' tagfile_name], tag_cells);
% if length(runno)<35
archive_string= sprintf('archiveme %s %s',civmid,runno{1});
% else
%     archive_string=sprintf(['\n WARNING: USE ARCHIVEME2! THERE ARE TOO MANY VOLULMES FOR SAFE USE OF ARCHIVEME\n' ...
%         'archiveme2 %s %s\n\n'],civmid,runno{1});
% end

if display_prompt
    fprintf('\n%s\n\n', archive_string);
end
