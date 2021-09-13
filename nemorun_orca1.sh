#!/bin/bash -l
###
### parallel job script example
###
## name of your job
#SBATCH --job-name=o1
#SBATCH --account=project_2000789
#SBATCH --time=00:15:00
#SBATCH --mem-per-cpu=2G
#SBATCH --ntasks=38
#SBATCH --partition=test

module purge
module load StdEnv intel/19.0.4 intel-mpi/18.0.5
module load hdf5/1.10.4-mpi netcdf-fortran/4.4.4 netcdf/4.7.0 
## run my MPI executable
srun ./nemo

