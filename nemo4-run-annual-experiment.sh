#!/bin/bash -l
# Use this script to prepare and launch a multiyear
# experiment split to several one year runs
#
# It is assument that the executable is already created
# using build-nemo4-${HGRID}-puhti.csc.fi.sh script,
# where HGRID=[ORCA2, ORCA1 or ORCA025]
# and the experiment template is in 
# ${SCRATCH}/${USER}/nemo4.0.6/cfgs/MY_${HGRID}_ICE/EXP00

SYEAR=1987
EYEAR=1988
ENAME=EXP01

HGRID=eORCA1
CONF=MY_${HGRID}_ICE
FORCE=JRA-55

PROJECT=project_2000789

# no need to change anything below here
PROJAPPL=/projappl/${PROJECT}
SCRATCH=/scratch/${PROJECT}

NEMOIN=${PROJAPPL}/nemoinput/${HGRID}
NEMOFORCE=${SCRATCH}/nemoforcing/${FORCE}
EDIR=${SCRATCH}/${USER}/nemo4.0.6/cfgs/${CONF}/${ENAME}

#prepare the first year (cold or restart)
mkdir -p ${EDIR}/${SYEAR}
cd ${EDIR}/${SYEAR}
ln -s ../../../SHARED/namelist_ref .
ln -s ../../../SHARED/namelist_ice_ref .
ln -s ../../../SHARED/grid_def_nemo.xml .
ln -s ../../../SHARED/field_def_nemo-oce.xml .
ln -s ../../../SHARED/field_def_nemo-ice.xml .
ln -s ../../../SHARED/field_def_nemo-pisces.xml .
ln -s ../../../SHARED/domain_def_nemo.xml .
ln -s ../../../SHARED/axis_def_nemo.xml .

ln -s ../../BLD/bin/nemo.exe nemo

ln -s ${NEMOIN}/eORCA_R1_zps_domcfg.nc
echo "                               0  0.0000000000000000E+00  0.0000000000000000E+00" > EMPave_old.dat
cp -p $PROJAPPL/$USER/nemoatpuhti/namelist_cfg.${HGRID}.${FORCE} namelist_cfg

# loop the remaining years here (restarts from the previous year)
for YR in $(seq $((${SYEAR}+1)) ${EYEAR});
do
    mkdir -p ${EDIR}/${YR}
    cd ${EDIR}/${YR}
done
