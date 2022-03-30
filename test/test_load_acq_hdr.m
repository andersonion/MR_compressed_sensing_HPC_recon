if ~exist('the_scanner','var')
    the_scanner=scanner('heike');
end
data_file='D:/workstation/scratch/N00003.work/.N00003.fid_tag';
[acq_hdr,S_hdr]=load_acq_hdr(the_scanner,data_file);
