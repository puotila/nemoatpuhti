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

#xios_version=2.5
#xios_dir=xios-${xios_version}
xios_dir=XIOS

compiler=gcc

module purge
module load StdEnv # gcc openmpi imported automatically
module load hdf5/1.12.2-mpi netcdf-c netcdf-fortran
module load subversion perl

cd $PROJAPPL/$USER
#svn co http://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/branchs/${xios_dir}
svn co http://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/trunk ${xios_dir}
# xios_revision=$(svn info | sed -n 's/Revision: \([0-9]\+\)/\1/p')

# Build

cd ${xios_dir}
cat > arch/arch-${compiler}-puhti.csc.fi.fcm <<EOF
%CCOMPILER      mpicc
%FCOMPILER      mpif90
%LINKER         mpif90

%BASE_CFLAGS    -w -std=c++11 -D__XIOS_EXCEPTION
%PROD_CFLAGS    -O3 -DBOOST_DISABLE_ASSERTS
%DEV_CFLAGS     -g -O2 
%DEBUG_CFLAGS   -g 

%BASE_FFLAGS    -D__NONE__
%PROD_FFLAGS    -O3
%DEV_FFLAGS     -g -O2
%DEBUG_FFLAGS   -g 

%BASE_INC       -D__NONE__
%BASE_LD        -lstdc++

%CPP            cpp 
%FPP            cpp -P
%MAKE           gmake
EOF

cat > arch/arch-${compiler}-puhti.csc.fi.path <<EOF
NETCDF_INCDIR="-I\${NETCDF_C_INSTALL_ROOT}/include -I\${NETCDF_FORTRAN_INSTALL_ROOT}/include"
NETCDF_LIBDIR="-L\${NETCDF_C_INSTALL_ROOT}/lib -L\${NETCDF_FORTRAN_INSTALL_ROOT}/lib"
NETCDF_LIB="-lnetcdff -lnetcdf"

MPI_INCDIR=""
MPI_LIBDIR=""
MPI_LIB="-lcurl"

HDF5DIR=\${HDF5_INSTALL_ROOT}
HDF5_INCDIR="-I\${HDF5DIR}/include"
HDF5_LIBDIR="-L\${HDF5DIR}/lib"
HDF5_LIB="-lhdf5_hl -lhdf5 -lhdf5 -lz"

BOOST_INCDIR="-I\${BOOST_ROOT}/include/boost"
BOOST_LIBDIR="-L\${BOOST_ROOT}/lib"
BOOST_LIB=""

OASIS_INCDIR="-I\${PWD}/../../oasis3-mct/BLD/build/lib/psmile.MPI1"
OASIS_LIBDIR="-L\${PWD}/../../oasis3-mct/BLD/lib"
OASIS_LIB="-lpsmile.MPI1 -lscrip -lmct -lmpeu"
EOF

cat > arch/arch-${compiler}-puhti.csc.fi.env <<EOF
export HDF5DIR=\${HDF5_INSTALL_ROOT}
export HDF5_INC_DIR=\${HDF5DIR}/include
export HDF5_LIB_DIR=\${HDF5DIR}/lib

export NETCDF_INC_DIR=\${NETCDF_C_INSTALL_ROOT}/include
export NETCDF_LIB_DIR=\${NETCDF_C_INSTALL_ROOT}/lib

export BOOST_INC_DIR=\${BOOST_ROOT}/include/boost
export BOOST_LIB_DIR=\${BOOST_ROOT}/lib
EOF

#./make_xios --prod --arch ${compiler}-puhti.csc.fi --job 8
./make_xios --prod --arch ${compiler}-puhti.csc.fi

