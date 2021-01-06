# MR_compressed_sensing_HPC_recon
Robust reconstruction of compressed sensing MR acquisitions, adapted for an HPC cluster running SLURM.

Copyright Duke University

Authors: Russell Dibb, James J Cook, Robert J Anderson, Nian Wang, G Allan Johnson

Compressed sensing reconstruction on a Bright computing cluster running SLURM Version 17.02.11(initial work at 2.5.7), with data originating from Agilent MRI scanners running VnmrJ Version 4.0_A.

One design goal of this code is to make the parts interchangeble enough that it can be adapted for other types of scanner by creating alternate modules.  However, this goal is not quite perfectly executed yet.  With each iteration, it is hoped that it will be easier to add Bruker, etc. support.

Relies on sparse MRI v0.2 supporting code from https://people.eecs.berkeley.edu/~mlustig/Software.html
( https://people.eecs.berkeley.edu/~mlustig/software/sparseMRI_v0.2.tar.gz ) 

Which relies on parts of Wavelab850 from http://www-stat.stanford.edu/~wavelab
( http://www-stat.stanford.edu/~wavelab/Wavelab_850/WAVELAB850.ZIP )

TODO: 
--clean up functions--
streaming_CS_recon_main_exec::process_CS_mask
extract_info_from_CStable
skipint2skiptable
write_or_compare_fid_tag


--eliminate functions--
specid_to_recon_file - spazzy spam kinda function obfuscating everything
readprocparCS - redundant with readprocpar
puller_glusterspaceCS_2 - all around bad
load_fid_hdr_details  - load_blk_hdr does nearly the same work as should be merged

--Break the mat file var loading obfuscation--
At a minimum switch to matfile object usage, ideally stop making everything double extra redundant.

--remove redundant abused data structures from matfiles--
