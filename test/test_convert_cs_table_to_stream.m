data_dir=getenv('WORKSTATION_DATA');
petableCS=fullfile(data_dir,'petableCS');

table_info=dir(petableCS);

for idx_t=1:numel(table_info)
    tn=table_info(idx_t).name;
    if ~reg_match(tn,'^CS[0-9]+') ... 
        || reg_match(tn,'CS[0-9]+.*.gz')
        continue;
    end
    tn_s=sprintf('stream_%s',tn);
    cs_t=fullfile(petableCS,tn);
    cs_st=fullfile(petableCS,tn_s);
    %if ~exist(cs_st,'file') && exist(cs_t,'file')
    try
        convert_cs_table_to_stream(cs_t,cs_st);
    catch merr
        fprintf('failed %s\t%s\n', cs_t, merr.message);
    end
end

