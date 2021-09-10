#!/bin/bash

set -ex

# NEMO build and install instructions for puhti.csc.fi
#
# 2018-12-11, Juha Lento, CSC
# 2018-12-14, Petteri Uotila, INAR/UH

nemo_version=4.0

compiler=intel
compiler_version=19.0.4
mpi=intel-mpi
mpi_version=18.0.5

module purge
module load StdEnv ${compiler}/${compiler_version} ${mpi}/${mpi_version}
module load netcdf/4.7.0 netcdf-fortran/4.4.4 hdf5/1.10.4-mpi

cd $PROJAPPL
# Checkout sources
svn co https://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/r4.0/r4.0.6
#svn co https://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/release-4.0
#svn co -r10645 http://forge.ipsl.jussieu.fr/nemo/svn/NEMO/trunk nemo4.0

cd r4.0.6
nemo_revision=$(svn info | sed -n 's/Revision: \([0-9]\+\)/\1/p')

cat > arch/arch-${compiler}-puhti.csc.fi.fcm <<EOF
%CC                  mpicc
%CFLAGS              -O0
%CPP                 cpp
%FC                  mpif90
%FCFLAGS             $(case $compiler in (gnu) echo '-fdefault-real-8 -O3 -funroll-all-loops -fcray-pointer -ffree-line-length-none';; (intel) echo '-O3 -i4 -r8 -fp-model precise -fno-alias -fpp';; esac)
%FFLAGS              %FCFLAGS
%LD                  mpif90
%LDFLAGS
%FPPFLAGS            -P -C -traditional-cpp
%AR                  ar
%ARFLAGS             rs
%MK                  make

%NCDF_HOME           $NETCDF_INSTALL_ROOT
%NCDFF_HOME          $NETCDF_FORTRAN_INSTALL_ROOT
%HDF5_HOME           $HDF5_INSTALL_ROOT
%XIOS_HOME           $PROJAPPL/xios-2.5
%OASIS_HOME          /not/defined
%NCDF_INC            -I%NCDF_HOME/include -I%NCDFF_HOME/include
%NCDF_LIB            -L%NCDF_HOME/lib -L%NCDFF_HOME/lib -lnetcdff -lnetcdf -L%HDF5_HOME/lib -lhdf5_hl -lhdf5 -lhdf5
%XIOS_INC            -I%XIOS_HOME/inc
%XIOS_LIB            -L%XIOS_HOME/lib -lxios -lstdc++

%USER_INC            %XIOS_INC %NCDF_INC
%USER_LIB            %XIOS_LIB %NCDF_LIB
EOF

./makenemo -j 8 -m ${compiler}-puhti.csc.fi -r GYRE_PISCES -n MY_GYRE del_key key_top

# run the experiment
cd cfgs/MY_GYRE/EXP00

sbatch << EOF
#!/bin/bash -l
###
### parallel job script example
###
## name of your job
#SBATCH --job-name=gyre
#SBATCH --account=project_2000789
#SBATCH --time=00:15:00
#SBATCH --mem-per-cpu=2G
#SBATCH --partition=test

module purge
module load StdEnv ${compiler}/${compiler_version} ${mpi}/${mpi_version}
module load netcdf/4.7.0 netcdf-fortran/4.4.4 hdf5/1.10.4-mpi

## run my MPI executable
srun ./nemo
EOF

