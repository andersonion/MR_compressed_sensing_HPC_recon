function active_reservation=get_reservation(resopt)
% resopt is a logical or string 
% This should work fine, even if CS_reservation is not set.
% it will just be a blank in that case.
active_reservation=getenv('CS_reservation'); 

% normal system variables, if these are set we should use these and ignore
% what the user said, empty strings are unset.
sbatch_r=getenv('SBATCH_RESERVATION');
slurm_r =getenv( 'SLURM_RESERVATION');
if ~isempty(resopt) && ischar(resopt) 
    active_reservation=resopt;
elseif ~isempty(sbatch_r)
    active_reservation=sbatch_r;
elseif ~isempty(slurm_r)
    active_reservation=slurm_r;
end
% Ensure that reservation exists
if (active_reservation)
    [~, res_check] = system(['scontrol show reservation ' active_reservation]);
    res_check = strtrim(res_check);
    failure_string = ['Reservation ' active_reservation ' not found'];
    if strcmp(res_check,failure_string)
        active_reservation = '';
    end
end
setenv('CS_reservation',active_reservation);
