input_fid='/home/mrraw/N220302_01/ser09.fid/fid';
fid_tag_file='D:/workstation/scratch/N00001.work/.N00001.fid_tag';

the_scanner=scanner('heike');
the_scanner.fid_get_tag(input_fid,fid_tag_file);
