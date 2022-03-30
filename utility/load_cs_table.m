function [skiptable,pa,pb,cs_factor]=load_cs_table(table_target,table_dims)
% function [skiptable,pa,pb,cs_factor]=LOAD_CS_TABLE(table_target,table_dims)
%
% Copyright Duke University
% Authors: James J Cook, G Allan Johnson

if ~exist('table_dims','var')|| nargout>1
    [table_dims,pa,pb,cs_factor]=cs_table_name_decode(table_target);
end
%% Open CS table and format into a bit mask (aka skiptable).
fid=fopen(table_target);
if ~reg_match(table_target,'stream')
    % potentially could use *char=>logical or uint.
    skiptable=fread(fid,inf,'*char');
    % convert to logical, and converts any unnecessary space chars to 0.
    skiptable=(skiptable=='1');
else
    % read stream table
    % table values can only be 16 or 8 bit, so we can use 16 bit safely
    [pt_data, read_end]=textscan(fid, '%d');
    if ~feof(fid)
        % make sure we read the whole file in becuase textscan will stop on
        % non-matching data. A single trailing blank line is expected, but
        % we'll let it be optional.
        lines=cell(0);
        while ~feof(fid) && numel(lines)<10
            lines{end+1} = fgetl(fid);
        end
        if numel(lines)> 1 || ~isempty(lines{1})
            warning('unexpected data after reading table stream %s',table_target);
            for ln=1:numel(lines)
                fprintf('%s\n',lines{ln});
            end
            error('table format not to spec, frightening!');
        end
    end
    pt_data=cell2mat(pt_data);
    pt_data=reshape(pt_data,[2,numel(pt_data)/2]);
    pt_data(1,:)=pt_data(1,:)+round(table_dims(1)/2);
    pt_data(2,:)=pt_data(2,:)+round(table_dims(2)/2);
    pts_t=sub2ind(table_dims,pt_data(1,:),pt_data(2,:));
    %pts_t=sub2ind(table_dims,pt_data(1:2:end),pt_data(2:2:end));
    skiptable=zeros(table_dims);
    skiptable(pts_t)=1;
    clear pts_t pt_data;
end
fclose(fid);

%% enforce exact size
table_elements=prod(table_dims);
if numel(skiptable)+10 < table_elements
    error('TABLE UNDERSIZED! %s has %d of %d expected',...
        table_target, numel(skiptable), table_elements)
end
while numel(skiptable) < table_elements
    % using a while is not necessary here, however if more than one 0 is
    % missing this will be extra spammy, which seems like a good thing.
    warning('TABLE UNDERSIZED! Adding 0''s to fill it out!');
    skiptable(end+1)=0;
end
if numel(skiptable) ~= table_elements
    funct=@warning;
    if numel(skiptable)-10 > table_elements
        funct=@error; end
    funct('TABLE oversize! truncating! (You may have had trailing spaces converted to 0.)');
    skiptable=skiptable(1:table_elements); % BJA - Trims off any zero padding
end
skiptable=reshape(skiptable, table_dims);
end
