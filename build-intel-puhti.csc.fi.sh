#!/bin/bash

set -ex

# XIOS build and install instructions for puhti.csc.fi
#
# 2018-12-11, Juha Lento, CSC
# 2019-09-28, Petteri Uotila, UH
#
# NOTE Could not find libcurl so installed it 
# in $PROJAPPL /projappl/project_2000789
#
# The following build instruction is based on:
# - http://forge.ipsl.jussieu.fr/ioserver/wiki/documentation

xios_version=2.5

compiler=intel
compiler_version=18.0.5
mpi=intel-mpi
mpi_version=18.0.5

module purge
module load ${compiler}/${compiler_version} ${mpi}/${mpi_version}
module load git netcdf/4.7.0 netcdf-fortran/4.4.4 hdf5/1.10.4-mpi

cd $PROJAPPL
svn co http://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/branchs/xios-${xios_version}
xios_revision=$(svn info | sed -n 's/Revision: \([0-9]\+\)/\1/p')

# Build

cd xios-${xios_version}
cat > arch/arch-${compiler}-puhti.csc.fi.fcm <<EOF
%CCOMPILER      mpicxx
%FCOMPILER      mpif90
%LINKER         mpif90
%BASE_CFLAGS    $(case $compiler in (intel|gnu) echo '-ansi';;esac)
%PROD_CFLAGS    -O3 -DBOOST_DISABLE_ASSERTS
%BASE_FFLAGS    -D__NONE__ -fpp $(case $compiler in (gnu) echo '-ffree-line-length-none';; esac)
%PROD_FFLAGS    -O3
%BASE_INC       -D__NONE__
%BASE_LD        -lstdc++
%CPP            cpp -P
%FPP            cpp -P -CC
%MAKE           make
EOF

cat > arch/arch-${compiler}-puhti.csc.fi.path <<EOF
NETCDF_INCDIR="-I${NETCDF_INSTALL_ROOT}/include -I${NETCDF_FORTRAN_INSTALL_ROOT}/include"
NETCDF_LIBDIR="-L${NETCDF_INSTALL_ROOT}/lib -L${NETCDF_FORTRAN_INSTALL_ROOT}/lib"
NETCDF_LIB="-lnetcdf -lnetcdff"
HDF5_INCDIR="-I${HDF5_INSTALL_ROOT}/include"
HDF5_LIBDIR="-L${HDF5_INSTALL_ROOT}/lib -L${PROJAPPL}/lib"
HDF5_LIB="-lhdf5_hl -lhdf5 -lhdf5 -lz -lcurl"
EOF

./make_xios --arch ${compiler}-puhti.csc.fi --job 8

