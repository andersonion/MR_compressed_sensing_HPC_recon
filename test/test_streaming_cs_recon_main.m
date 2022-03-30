% CS_table='CS480_8x_pa18_pb54';
%% existing heike data checking
scanner_name='heike';s_l='N';
patient='N220307_01';
acquisition='ser10';data=strjoin({patient,acquisition},'/');
patient='N220304_01';
acquisition='ser10';data=strjoin({patient,acquisition},'/');
dig=2;

%% existing kamy checking, may not be best dataset as its 1024x380x380
scanner_name='kamy';s_l='S';
% S211215_01/ser11.fid
patient='S211215_01';
acquisition='ser11.fid';data=strjoin({patient,acquisition},'/');
acquisition='ser10';data=strjoin({patient,acquisition},'/');
dig=2;


%% new scanner data testing
scanner_name='new9t';s_l='N';
scanner_name='local9t';s_l='N';
patient='';
acquisition='3dmra';data=acquisition;
acquisition='smfov';data=acquisition;
dig=dig+2;

%% real test of fast spin echo from new scanner
scanner_name='grumpy';s_l='N';
%--no--! acquisition='8_000_0';data=acquisition; 
acquisition='dev/MRD/1/8';data=acquisition;  dig=dig+2;
acquisition='dev/MRD/1/39';data=acquisition;  dig=dig+2;
% acquisition='dev/MRD/1/40';data=acquisition;  dig=dig+2;

%% set args
main_args={'planned_ok', 'live_run','debug_mode=50',...
    'skip_target_machine_check','last_volume=1',...
    'iteration_strategy=1x1','chunk_size=5','target_machine=localhost',...
    'keep_work','scanner_user=mrs'};
%% pick runno for either of us to test with
if ~strcmp(getenv('USERNAME'),'jjc29')
    runno=sprintf('%s%05i',s_l,dig);
    streaming_CS_recon_main_exec('heike',runno,data,...
    main_args{:});
else
    runno=sprintf('%s%05i',s_l,dig+1);
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
