function [skiptable,pa,pb,cs_factor]=load_cs_table(table_target,table_dims)
% function [skiptable,pa,pb,cs_factor]=LOAD_CS_TABLE(table_target,table_dims)
if isempty(table_dims)
    table_dims=cs_table_name_decode(table_target);
end
%% Open CS table and format into a bit mask (aka skiptable).
fid=fopen(table_target);
% potentially could use *char=>logical or uint.
skiptable=fread(fid,inf,'*char');
fclose(fid);
% convert to logical, and converts any unnecessary space chars to 0.
skiptable=(skiptable=='1');

%% enforce exact size
table_elements=prod(table_dims);
while numel(skiptable) < table_elements
    % using a while is not necessary here, however if more than one 0 is
    % missing this will be extra spammy, which seems like a good thing.
    warning('TABLE UNDERSIZED! Adding 0''s to fill it out!');
    skiptable(end+1)=0;
end
if numel(skiptable) ~= table_elements
    warning('TABLE oversize! truncating! (You may have had trailing spaces converted to 0.)');
    skiptable=skiptable(1:table_elements); % BJA - Trims off any zero padding
end
skiptable=reshape(skiptable, table_dims);
end
