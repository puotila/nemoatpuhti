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
E0DIR=${SCRATCH}/${USER}/nemo4.0.6/cfgs/${CONF}/EXP00
EDIR=${SCRATCH}/${USER}/nemo4.0.6/cfgs/${CONF}/${ENAME}

init_single_year() {
    mkdir -p ${EDIR}/$1
    cd ${EDIR}/$1

    ln -sf ../../../SHARED/namelist_ref .
    ln -sf ../../../SHARED/namelist_ice_ref .
    ln -sf ../../../SHARED/grid_def_nemo.xml .
    ln -sf ../../../SHARED/field_def_nemo-oce.xml .
    ln -sf ../../../SHARED/field_def_nemo-ice.xml .
    ln -sf ../../../SHARED/field_def_nemo-pisces.xml .
    ln -sf ../../../SHARED/domain_def_nemo.xml .
    ln -sf ../../../SHARED/axis_def_nemo.xml .

    cp -pf ${E0DIR}/iodef.xml .
    cp -pf ${E0DIR}/context_nemo.xml .
    cp -pf ${E0DIR}/file_def_nemo-ice.xml .
    cp -pf ${E0DIR}/file_def_nemo-oce.xml .
    cp -pf ${E0DIR}/file_def_nemo-pisces.xml .

    ln -sf ../../BLD/bin/nemo.exe nemo

    ln -sf ${NEMOIN}/eORCA_R1_zps_domcfg.nc
    echo "                               0  0.0000000000000000E+00  0.0000000000000000E+00" > EMPave_old.dat

    cp -p $PROJAPPL/$USER/nemoatpuhti/namelist_cfg.${HGRID}.${FORCE} namelist_cfg
    cp -pf ${E0DIR}/namelist_ice_cfg .
}

write_single_year_runscript() {
    cd ${EDIR}/${YR}
    cat << EOF > nemorun.sh
#!/bin/bash -l
#SBATCH --job-name=o1_$1
#SBATCH --account=project_2000789
#SBATCH --mem-per-cpu=2G
#SBATCH -t 00:01:00
#SBATCH -n 36
#SBATCH -p test

module purge
module load StdEnv intel/19.0.4 intel-mpi/18.0.5
module load hdf5/1.10.4-mpi netcdf-fortran/4.4.4 netcdf/4.7.0 

srun ./nemo
EOF
}

#####

#prepare the first year (cold or restart)
init_single_year ${SYEAR}
write_single_year_runscript ${SYEAR}
cd ${EDIR}/${SYEAR}
#sbatch nemorun.sh
jobid=`sbatch --parsable nemorun.sh`

# loop the remaining years here (restarts from the previous year)
for YR in $(seq $((${SYEAR}+1)) ${EYEAR});
do
    init_single_year ${YR}
    write_single_year_runscript ${YR}
    jobid=`sbatch --dependency=afterok:$jobid --parsable nemorun.sh`
done

