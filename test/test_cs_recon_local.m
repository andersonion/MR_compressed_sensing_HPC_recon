
%% set file and runno
cs_table='c:/workstation/data/petableCS_stream/other/stream_CS256_16x_pa18_pb73';
mrd_file='c:/smis/dev/Temp/se_test_const_phase.mrd';

%% fast vs good
% good
iters='iteration_strategy=6x10';
% fast(nominally just an fft but with all the compressed sensing machinery
% engaged)
% iters='iteration_strategy=1x1';

%% do setup
% these are normally handled by workstation setup, but we dont wanna this
% to be a fully standard workstation, this is only for testing.
if strcmp(getenv('WORKSTATION_DATA'),'')
    setenv('WORKSTATION_DATA','c:/workstation/data');
end
if strcmp(getenv('BIGGUS_DISKUS'),'')
    setenv('BIGGUS_DISKUS','c:/workstation/scratch');
end
if strcmp(getenv('WORKSTATION_HOME'),'')
    setenv('WORKSTATION_HOME','c:/workstation/code')
end
if strcmp(getenv('WKS_SETTINGS'),'')
    setenv('WKS_SETTINGS','c:/workstation/code/pipeline_settings')
end
f_path=which('load_mrd');
if isempty(f_path)
    current_dir=pwd;
    cd c:/workstation/code/shared/pipeline_utilities
    startup
    cd(current_dir);
end
clear f_path;


%% adjust input for CS_recon 
scanner_name='grumpy';s_l='N';
formatOut = 'yyyymmdd_hh';
runno=sprintf('%s%s',s_l,datestr(now,formatOut));
%[~,cs_table]=fileparts(cs_table);

%% set args 
% normal iteration count
main_args={'planned_ok', 'live_run','debug_mode=50',...
    'skip_target_machine_check','last_volume=1',...
    'chunk_size=5','target_machine=localhost',...
    'keep_work','scanner_user=mrs',iters};
if exist('cs_table','var')
    main_args{end+1}=sprintf('CS_table=%s',cs_table);
end
%% pick runno for either of us to test with
streaming_CS_recon_main_exec(scanner_name,runno,mrd_file,...
    main_args{:});