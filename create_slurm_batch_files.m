function [ file_name ] = create_slurm_batch_files(file_name,cell_array_of_lines_to_write,slurm_option_struct )
% Formats, in a consistent manner, batch files to be called from sbatch
%   
    sha_bang = '#!/bin/bash';
   
  
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
    fprintf(fid,'%s\n',sha_bang);
    
    if ~exist('slurm_option_struct','var')
        slurm_option_struct = struct;
    end
    
    slurm_fields = fieldnames(slurm_option_struct);
    
    for sf = 1:length(slurm_fields)
        slurm_option=slurm_fields(sf);
        slurm_option=slurm_option{1};
        if isempty(slurm_option)
            % avoid adding blank options.
            continue;
        end
        
        slurm_option_parameter = getfield(slurm_option_struct,slurm_option);
        
        % Replace underscores with dashes, as per slurm/sbatch usage  
        slurm_option = strjoin(strsplit(slurm_option,'_'),'-');
        
        
        if isnumeric(slurm_option_parameter)
            slurm_option_parameter=num2str(slurm_option_parameter);
        end
        
        if length(slurm_option) == 1
            s_opt_string = ['-' slurm_option ' '];
        else
            s_opt_string = ['--' slurm_option '='];
        end
        
        slurm_string = ['#SBATCH ' s_opt_string slurm_option_parameter];
        fprintf(fid,'%s\n',slurm_string );
    end    
    
    if iscell(cell_array_of_lines_to_write)
       num_lines =  length(cell_array_of_lines_to_write);
    else
       num_lines = 1;
    end
        
    for cc = 1:num_lines
       if iscell(cell_array_of_lines_to_write)
            c_command =cell_array_of_lines_to_write{cc};
       else
           c_command =cell_array_of_lines_to_write(:);
       end
        semicolon_string='';
        if ~strcmp(c_command(end),';')
            semicolon_string=';';
        end
        fprintf(fid,'%s%s\n',c_command,semicolon_string );
    end
    
    fclose(fid);
end

