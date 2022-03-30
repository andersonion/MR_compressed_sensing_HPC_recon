function convert_cs_table_to_stream(cs_table,stream_out)
% function CONVERT_CS_TABLE_TO_STREAM(cs_table,stream_out)
% loads previous version of cs table and converts it into the new stream of
% text values

if reg_match(cs_table,'stream')
    warning('this appears to already be a stream table, quiting');
    return;
end
if ~exist('stream_out','var')
    [p,n,e]=fileparts(cs_table);
    stream_out=fullfile(p,sprintf('stream_%s.txt',n));
end
if exist(stream_out,'file')
    [s,sout]=system(sprintf('touch -r %s %s', cs_table, stream_out));
    assert(s==0,sout);
    warning('existing file, NOT OVERWRITING');
    return;
end
%% do work
mask = load_cs_table(cs_table);
save_cs_stream_table(mask,stream_out);
%% conversion check
m2=load_cs_table(stream_out,size(mask));
if nnz(m2-mask)> 0
    disp('reload fail look at pictures');
    disp_vol_center(mask,0,100);
    disp_vol_center(m2,0,101);
    delete(stream_out);
    error('cs table conversion failed');
end
[s,sout]=system(sprintf('touch -r %s %s', cs_table, stream_out));
assert(s==0,sout);
