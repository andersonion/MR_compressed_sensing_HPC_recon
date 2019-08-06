function streaming_CS_restart(runno,opt_text)
%  streaming_CS_restart(runno,opt_text)
% Restarts a streaming CS recon based on the runno string.
% optionally add more options in opt_text, a plain text field appended to
% command
mf=matfile(fullfile(getenv('BIGGUS_DISKUS'),[runno '.work' ],[runno 'recon.mat']));
mfo=mf.options;
if ~exist('opt_text','var')
    opt_text='';
end
if isfield(mfo,'CS_reservation')
    if ~isempty(mfo.CS_reservation)
        opt_text=sprintf('CS_reservation=%s %s',mfo.CS_reservation,opt_text);
    end
end
%% temp code to get over bad reporting :p
% init count, and init count 2
ic=numel(mf.xfmWeight);
ic2=numel(mf.TVWeight);
if ic ~= ic2
    error('xfmWeight is array, with length %i, but TVWeight length is %i, dont know what to do!',ic,ic2);
    % error('iteration_strategy missing from optionslist, this code was updated without care for backward compatibility. ');
end
% end of temp code. 

%% craft and display command 
cmd=sprintf('streaming_CS_recon %s %s %s %s %s',...
    mf.scanner_name, runno, mf.study, mf.agilent_series,...
    sprintf('CS_table=%s iteration_strategy=%s xfmWeight=%0.3f TVWeight=%0.4f %s',...
    mfo.CS_table,    sprintf('%ix%x',mf.Itnlim/ic,ic),    mf.xfmWeight(1,1), mf.TVWeight(1,1), ...
    sprintf('target_machine=%s %s',mf.target_machine,opt_text) )... 
    );
%% hack in special live_run support
live_run=0;
if ~isempty(regexpi(opt_text,'live_run'))
    % set "real name" and open paren
    cmd=strrep(cmd,'streaming_CS_recon ','streaming_CS_recon_main_exec(''');
    % convert all args to explicit strings ([[:space:]] -> ',')
    cmd=strrep(cmd,' ',''',''');  
    % add close paren
    cmd=sprintf('%s'');',cmd); 
    live_run=1;
end
disp(cmd);
fprintf('\n\nWill run above command in 4 seconds press ctrl+c to abort\n');
pause(4)
%% run cmd
if live_run
    db_inplace(mfilename,'LIVERUN DEBUGGING, start now')
    eval(cmd);
else
    system(cmd);
end
