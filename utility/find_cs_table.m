function CS_table=find_cs_table(the_scanner,ntraces,typical_pa,typical_pb)
%options.CS_table = input('Please enter the name of the CS table used for this scan.','s');
% ls_cmd= [ 'ssh ' the_scanner.user '@' the_scanner.host_name ' ''cd /home/vnmr1/vnmrsys/tablib/; ls CS*_*x_*'''];
ls_cmd = sprintf('ssh %s@%s cd %s; ls CS*_*x_*',the_scanner.user, the_scanner.host_name,the_scanner.skip_table_directory);
[~,available_tables]=ssh_call(ls_cmd);
valid_tables=select_valid_tables(available_tables,ntraces,typical_pa,typical_pb);
if numel(valid_tables)>1
    log_msg=sprintf('CS_table ambiguous, If a table matches our default params,\n');
    log_msg=sprintf('%sit will be listed last.\n',log_msg);
    log_msg=sprintf('%sFor best clarity please specify when in streaming mode.\n',log_msg);
    log_msg=sprintf('%s\t(otherwise you will need to wait until the entire scan completes).\n',log_msg);
    log_msg=sprintf('Vaild tables for pa %0.2f and pb %0.2f this data:\n\t%s\n%s',...
        typical_pa,typical_pb,strjoin(valid_tables,'\n\t'),log_msg);
    yet_another_logger(log_msg,3,log_file,0);
    fprintf('  (Ctrl+C to abort)\n');
    options.CS_table='';
    while ~reg_match(options.CS_table, ...
            sprintf('^%s$',strjoin(valid_tables,'|') )  )
        options.CS_table=input( ...
            sprintf('Type in a name to continue\n'),'s');
    end
elseif numel(valid_tables)==1
    CS_table=valid_tables{1};
    warning('Only one possible CS_table found. If this is incorrect Ctrl+c now.\n%s',CS_table);
    pause(5);
else
    % no valid tables
    error('Table listing: %s\nCS_table not specified and couldn''t find valid CS table,\n\tMaybe this isn''t a CS acq?',available_tables);
end

