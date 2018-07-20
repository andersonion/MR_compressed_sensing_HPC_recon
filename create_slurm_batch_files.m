function [ file_name ] = create_slurm_batch_files(file_name,cell_of_commands,slurm_option_struct )
% Formats, in a consistent manner, batch files to be called from sbatch
%   
  
    if ~exist('slurm_option_struct','var')
        slurm_option_struct = struct;
    end
    file_name_array = strsplit(file_name,'/');
    
    if ~exist(file_name,'dir')   
        file_name_array(length(file_name_array))=[];
        if ~strcmp(file_name_array{length(file_name_array)},'sbatch')
            file_name_array{length(file_name_array)+1} = 'sbatch';
        end
        default_dir=strjoin(file_name_array,'/');   
    else 
        if ~strcmp(file_name_array{length(file_name_array)},'sbatch')
            file_name_array{length(file_name_array)+1} = 'sbatch';
        end
        default_dir=strjoin(file_name_array,'/');   
        file_name = [default_dir '/tmp_sbatch_job.bash'];
    end
    
    if ~exist(default_dir,'dir')
       mkdir(default_dir);
    end
    
    fid=fopen(file_name,'w'); % Note that this will overwrite existing files!
    if fid<0;
        ed='';% error details
        if numel(file_name)>250
            ed=sprintf(': the name may be to long');
        end
        error('Couldnt open file %s%s',file_name,ed);
    end
    
    %% check for special handling with partition and reservation.
    % we'll have partition superseed reservation, eg, if there is a
    % partion, and its not in the reservation, we will set reservation to
    % blank to prevent its use. This doesnt handle the "normal" env
    % variables SLURM_RESERVATION and SBATCH_RESERVATION. I think those
    % should be handled by setting our res struct to inclue them for
    % uniformity. Not bothering for now. 
    if isfield(slurm_option_struct,'p') ...
            && ( isfield(slurm_option_struct,'reservation') && ~isempty(slurm_option_struct.reservation) )
        [s,o]=system(sprintf('scontrol show reservation %s',slurm_option_struct.reservation));
        resinfo=struct;
        %PartitionName=matlab
        % scontroloutput is a wierd block of lines with name=value keys.
        % these loops over each line, breaking apart the name=value keys,
        % ignoreing any issues in that separation.
        ol=strsplit(o,'\n');%olines
        if s==0 && numel(ol)>3
            for ln=1:numel(ol)
                lp=strsplit(ol{ln},' ');% line parts
                for pn=1:numel(lp)
                    if ~isempty(strfind(lp{pn},'='))
                        nv=strsplit(lp{pn},'=');% name value
                        if ~isempty(nv{2}) && numel(nv)==2
                            resinfo.(nv{1})=nv{2};
                        elseif strcmp(nv{1},'TRES')
                            resinfo.(nv{1})=strjoin(nv{2:end},'=');
                        elseif numel(nv)>2
                            warning('error parsing partition info, line:%s, segment:%s',ol{ln},lp{pn});
                        end
                    end
                end
            end
        else
            resinfo.PartitionName='';
        end
        if isempty(regexpi(resinfo.PartitionName,['.*' slurm_option_struct.p '.*']))
            slurm_option_struct.reservation='';
        end
    end
    
    %% Write options to top of bash batch file
    sha_bang = '#!/bin/bash';
    fprintf(fid,'%s\n',sha_bang);
    slurm_fields = fieldnames(slurm_option_struct);
    for sf = 1:length(slurm_fields)
        slurm_option=slurm_fields{sf};
        if isempty(slurm_option)
            % avoid adding blank options.
            % except its desireable some of the time.
            % continue;
        end
        
        slurm_option_value = slurm_option_struct.(slurm_option);
        
        % Replace underscores with dashes, as per slurm/sbatch usage  
        slurm_option = strjoin(strsplit(slurm_option,'_'),'-');
        if isnumeric(slurm_option_value)
            slurm_option_value=num2str(slurm_option_value);
        end
        
        if length(slurm_option) == 1
            s_opt_string = ['-' slurm_option ' '];
        else
            s_opt_string = ['--' slurm_option '='];
        end
        
        slurm_string = ['#SBATCH ' s_opt_string slurm_option_value];
        fprintf(fid,'%s\n',slurm_string );
    end    
    %% write commands to bash batch file
    if iscell(cell_of_commands)
       num_lines =  length(cell_of_commands);
    else
       num_lines = 1;
    end
        
    for cc = 1:num_lines
       if iscell(cell_of_commands)
            c_command =cell_of_commands{cc};
       else
           c_command =cell_of_commands(:);
       end
        semicolon_string='';
        if ~strcmp(c_command(end),';')
            semicolon_string=';';
        end
        fprintf(fid,'%s%s\n',c_command,semicolon_string );
    end
    
    fclose(fid);
end

