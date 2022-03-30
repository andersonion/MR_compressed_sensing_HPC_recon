

t='D:\ProjectSpace\jjc29\mrsolutions\to_mr_solutions\CS256_8x_pa18_pb54';
[size_t,pa,pb,cs_factor]=cs_table_name_decode(t);
m=load_cs_table(t,size_t);
tn='stream_table_CS256_8x_pa18_pb54.txt';
delete(tn);
save_cs_stream_table(m,tn);
[size_t,pa,pb,cs_factor]=cs_table_name_decode(tn);

wkdir='D:\workstation\scratch\N00007.work'
tn='stream_table_CS256_1x_pa18_pb54.txt';
m=ones(256);
save_cs_stream_table(m,fullfile(wkdir,tn));


wkdir='D:\workstation\scratch\N00007.work'
tn='stream_table_CS128_1x_pa18_pb54.txt';
m=ones(128);
save_cs_stream_table(m,fullfile(wkdir,tn));


m2=load_cs_table(tn,size_t);

if nnz(m2-m)> 0
    disp('reload fail look at pictures');
    disp_vol_center(m,0,100);
    disp_vol_center(m2,0,101);
end

sizes=[128,192,256,360,380,384,480,512,640,768,992,1024,1152,1280,1536];
t_dir=getenv('TEMP');
fprintf('Required min compression:\n');
max_bytes=786432;
max_elements=max_bytes;
for sz=sizes

    %%{
    if sz>2^8
        % each element needs a 16-bit word to store
        max_elements=max_bytes/2;
    end
    % every point needs 2 data elements
    max_coords=(max_elements/2);
    % compression factor
    cf=double(ceil(sz^2/max_coords*100))/100;
    cf=max(cf,1);
    %}
%{
    success=0;
    t=zeros(sz);
    cf=1;
    while ~success
        ds_t=t;
        ds_t(1:cf:end)=1;
        test_table=fullfile(t_dir,sprintf('stream_CS%d_%dx_pa99_pb99',sz,cf));
        try
            save_cs_stream_table(ds_t,test_table);
            delete(test_table);
            success=1;
        catch merr
            fprintf('')
            cf=cf+1;
        end
    end
%}
    fprintf('% 8d x%0.2f\n',sz,cf);
end
