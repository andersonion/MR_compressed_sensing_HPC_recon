input_fid='/home/mrraw/N220302_01/ser09.fid/fid';
fid_tag_file='D:/workstation/scratch/N00001.work/.N00001.fid_tag';

host='heike.dhe.duke.edu';
user='omega';
b_setup.header_size=32;
b_setup.block_header=28;
b_setup.byte_count=100;
% b_setup.block_size=
% b_setup.selected_block=1

file_extract_bytes(input_fid, b_setup, fid_tag_file, host,user);
