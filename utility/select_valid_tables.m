function cell_of_tables=select_valid_tables(cell_of_tables,ntraces,def_pa,def_pb)
%
% Copyright Duke University
% Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson
if ~iscell(cell_of_tables)
    warning('A cell of tables is preferred to just a big string');
    cell_of_tables=strsplit(strtrim(cell_of_tables));
end
% cell_of_tables=select_valid_tables(cell_of_tables,ntraces,def_pa,def_pb)
% given the ntraces from your acq reduce the tables to the only ones valid
defacto_table='';
for i_t=numel(cell_of_tables):-1:1
    try
        % [~,y,z,pa,pb,ds_lvl]=extract_info_from_CStable(cell_of_tables{i_t},1);
        [m_dims,pa,pb,cs_factor]=cs_table_name_decode(cell_of_tables{i_t});
        y=m_dims(1);z=m_dims(2);
        if y*z/cs_factor~=ntraces
            cell_of_tables(i_t)=[];
            continue;
        end
        if pa==def_pa && pb==def_pb
            defacto_table=cell_of_tables{i_t};
            cell_of_tables(i_t)=[];
        end
    catch err
        %{
        warning(err.message);
        fprintf('name err? %s\n',cell_of_tables{i_t});
        %}
        cell_of_tables(i_t)=[];
    end
end
if ~isempty(defacto_table)
    cell_of_tables=[cell_of_tables,defacto_table];
end
