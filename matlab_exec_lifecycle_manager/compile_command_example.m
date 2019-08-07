function compile_command_example
% function compile_command_example
% an example of using the compile_command__allpurpose function, so that we'll support compiling in parallel.
% The expectation is for each exec you want managed you'll replicate this function to harden the compile information.
% Compile all support this file and function must be named compile_command_ANYTHING, 
% NOTE: the anything is not connected to your final executeable name.
%
% For the example, the name of the function is "example". 
% You can also use the path to the mfile(with or without .m).
%
%optional shell env var to be cleared.
% if your code uses a SHELL Var to determine its path at run time for any reason
exec_env_var='';
%optional, but required if using exec_env_var, can be empty.
% generally wont need this any longer as the code to find all dependencies works
include_files = {};
% in this context "example" is the function name of the exec we want to compile.
compile_command__allpurpose('example',include_files,exec_env_var);
