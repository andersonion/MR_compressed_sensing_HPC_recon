%% do setup
if strcmp(getenv('WORKSTATION_DATA'),'')
    setenv('WORKSTATION_DATA','c:/workstation/data');
end
if strcmp(getenv('BIGGUS_DISKUS'),'')
    getenv('BIGGUS_DISKUS','c:/workstation/scratch');
end
if strcmp(getenv('WORKSTATION_HOME'),'')
    getenv('WORKSTATION_HOME','c:/workstation/code')
end
%% adjust input for CS_recon 
scanner_name='grumpy';s_l='N';
%% set file and runno
cs_table='c:/workstation/data/petableCS_stream/other/stream_CS256_16x_pa18_pb73';
data='c:/smis/dev/Temp/se_test_const_phase.mrd';
runno='Test_data';
%% set diffusion test
cs_table='C:\workstation\data\petableCS_stream\stream_CS256_8x_pa18_pb54';
runno='N20220506_01';
% scanner='local9t'; data='d:\workstation\scratch\N20220506_01\_p1_diffusion_a46b5\volume_index.txt';
% rel-mode
% data='N20220506_01\_p1_diffusion_a46b5\volume_index.txt';
% full_mode, switch to our fav mrraw?
%data='d:\smis\N20220506_01\_p1_diffusion_a46b5\volume_index.txt';

runno='N60003t';
data='d:/smis/N20220518_00/_00_ISO46_5b0/volume_index.txt';


%runno='N60004t';
%data='d:/smis/N20220519_00/_01_ISO46_5b0/volume_index.txt';

runno='ortho_diffusion_fs';
[s,sout]=system('declare -x BIGGUS_DISKUS=/privateShares/jjc29');
runno='ortho_diffusion_fs_1i';
cs_table='C:\workstation\data\petableCS_stream\stream_CS256_1x_pa1_pb1';
data='/d/smis/N20220520_01/_01_ortho/volume_index.txt';

%% set args 
% normal iteration count
iters='iteration_strategy=6x10';
% test iteration count
iters='iteration_strategy=1x1';
% do 1 vol only
main_args={'planned_ok', 'live_run','debug_mode=50',...
    'skip_target_machine_check','last_volume=1',...
    'chunk_size=5','target_machine=localhost',...
    'keep_work','scanner_user=mrs',iters};
% do last of test volumes WHICH IS NOT COMPLETE
main_args={'planned_ok', 'live_run','debug_mode=50',...
    'skip_target_machine_check','first_volume=2',...
    'chunk_size=5','target_machine=localhost',...
    'keep_work','scanner_user=mrs',iters};

% do all vols
%{
main_args={'planned_ok', 'live_run','debug_mode=50',...
    'skip_target_machine_check',...
    'chunk_size=5','target_machine=localhost',...
    'keep_work','scanner_user=mrs',iters};
%}
if exist('cs_table','var')
    main_args{end+1}=sprintf('CS_table=%s',cs_table);
end
%% pick runno for either of us to test with
if ~strcmp(getenv('USERNAME'),'jjc29') && ~strcmp(getenv('USER'),'jjc29')
    runno=sprintf('%s%05i',s_l,dig);
    streaming_CS_recon_main_exec('heike',runno,data,...
    main_args{:});
else
    if ~exist('runno','var')
        runno=sprintf('%s%05i',s_l,dig+1);
    end
    % somewhat recognizeable shape
    % dims=[256,128,16,5]  'c:/smis/DATA/3dmra.mrd '
    % dont know how to start looking at this epi data
    % dims=[31680,30,2] 'c:/smis/DATA/epi.mrd'
    % looks lke a simple phantom
    % dims=[512,512] 'c:/smis/DATA/Smfov.mrd'
    % {
    streaming_CS_recon_main_exec(scanner_name,runno,data,...
        main_args{:});
    %}
    %{
    base_workdir=fullfile(getenv('BIGGUS_DISKUS'),sprintf('%s.work',runno));
    recon_file=fullfile(base_workdir,sprintf('%s_recon.mat',runno));
    recon_mat=matfile(recon_file,'Writable',true);

    mth=0;
    % volume_number is 1-indexed becuase its for matlab work
    volume_number=mth+1;
    volume_runno=sprintf('%s_m%02i',runno,mth);
    starting_point = volume_manager_exec(recon_file, volume_runno, volume_number,base_workdir);

    volume_dir=fullfile(base_workdir,volume_runno);
    setup_variables= fullfile(volume_dir,   [ volume_runno '_setup_variables.mat']);
    volume_cleanup_for_CSrecon_exec(setup_variables,recon_mat.original_dims);
    
    deploy_procpar_handlers(setup_variables)
    %}
end
