# MR_compressed_sensing_HPC_recon
Robust reconstruction of compressed sensing MR acquisitions, adapted for an HPC cluster running SLURM.

Compressed sensing reconstruction on a Bright computing cluster running SLURM Version 2.5.7, with data originating from Agilent MRI scanners running VnmrJ Version 4.0_A.

One design goal of this code is to make the parts interchangeble enough that it can be adapted for other types of scanner by creating alternate modules.  However, this goal is not quite perfectly executed yet.  With each iteration, it is hoped that it will be easier to add Bruker, etc. support.

Relies on sparse MRI v0.2 supporting code from https://people.eecs.berkeley.edu/~mlustig/Software.html
( https://people.eecs.berkeley.edu/~mlustig/software/sparseMRI_v0.2.tar.gz ) 

Which relies on parts of Wavelab850 from http://www-stat.stanford.edu/~wavelab
( http://www-stat.stanford.edu/~wavelab/Wavelab_850/WAVELAB850.ZIP )
