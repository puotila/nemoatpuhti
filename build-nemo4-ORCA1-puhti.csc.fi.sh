#!/bin/bash

set -ex

# NEMO build and install instructions for puhti.csc.fi
#
# 2018-12-11, Juha Lento, CSC
# 2018-12-14, Petteri Uotila, INAR/UH
# 2021-01-28, Petteri Uotila, INAR/UH
# 2021-09-10, Petteri Uotila, INAR/UH

nemo_version=4.0.6

compiler=intel
compiler_version=19.0.4
mpi=intel-mpi
mpi_version=18.0.5

module purge
module load StdEnv ${compiler}/${compiler_version} ${mpi}/${mpi_version}
module load netcdf/4.7.0 netcdf-fortran/4.4.4 hdf5/1.10.4-mpi

export PROJAPPL=/projappl/project_2000789
export SCRATCH=/scratch/project_2000789

mkdir -p ${SCRATCH}/${USER}
cd ${SCRATCH}/${USER}
# Checkout sources
svn co https://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/r4.0/r${nemo_version} nemo${nemo_version}

cd nemo${nemo_version}

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

./makenemo -j 8 -m ${compiler}-puhti.csc.fi -d "OCE ICE" -r ORCA2_ICE_PISCES -n MY_ORCA1_ICE del_key "key_top"

# get input data and run the experiment
ENAME=EXP00
cd cfgs/MY_ORCA1_ICE/${ENAME}

ln -s $SCRATCH/nemoinput/ORCA1/ORCA_R1_zps_domcfg.nc
echo "                               0  0.0000000000000000E+00  0.0000000000000000E+00" > EMPave_old.dat

ln -s $SCRATCH/nemoinput/ORCA1/mixing_power_bot.nc .
ln -s $SCRATCH/nemoinput/ORCA1/mixing_power_pyc.nc .
ln -s $SCRATCH/nemoinput/ORCA1/mixing_power_cri.nc .
ln -s $SCRATCH/nemoinput/ORCA1/decay_scale_bot.nc .
ln -s $SCRATCH/nemoinput/ORCA1/decay_scale_cri.nc .


cp -p $PROJAPPL/$USER/nemoatpuhti/namelist_cfg.orca1 namelist_cfg
cp -p $PROJAPPL/$USER/nemoatpuhti/nemorun_orca1.sh .

sbatch << EOF
#!/bin/bash -l
###
### parallel job script example
###
## name of your job
#SBATCH --job-name=orca1
#SBATCH --account=project_2000789
#SBATCH --mem-per-cpu=2G
## how long a job takes, wallclock time hh:mm:ss
#SBATCH -t 00:15:00
## the number of processes (number of cores)
#SBATCH -n 36
## queue
#SBATCH -p test

module purge
module load StdEnv ${compiler}/${compiler_version} ${mpi}/${mpi_version}
module load netcdf/4.7.0 netcdf-fortran/4.4.4 hdf5/1.10.4-mpi

## run my MPI executable
srun ./nemo
EOF
