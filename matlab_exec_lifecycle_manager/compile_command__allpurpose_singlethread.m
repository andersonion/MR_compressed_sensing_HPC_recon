function compile_dir=compile_command__allpurpose_singlethread(source_filename,include_files,exec_env_var)
% see help for compile_comman__allpurpose
% this just forces the singlethreaded option into mcc
compile_dir=compile_command__allpurpose(source_filename,include_files,exec_env_var,'-R -singleCompThread');
