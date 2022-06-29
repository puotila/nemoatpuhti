#!/bin/bash -l
# Use this script to prepare and launch a multiyear
# experiment split to several one year runs
#
# It is assument that the executable is already created
# using build-nemo4-${HGRID}-puhti.csc.fi.sh script,
# where HGRID=[ORCA2, ORCA1 or ORCA025]
# and the experiment template is in 
# ${SCRATCH}/${USER}/nemo4.0.6/cfgs/MY_${HGRID}_ICE/EXP00

# horizontal grid
HGRID=eORCA1
# name of NEMO configuration
CONF=MY_${HGRID}_ICE
# experiment directory in that configuration
ENAME=EXP01
# atmospheric forcing
#FORCE=JRA-55
FORCE=default
# how many cycles (e.g. years) to run 
ncycles=1
# experiment name [check this is ok]
cn_exp="eORCA1.L75"
# initial date of the experiment [check this is ok]
nn_date0=19580101
# CSC computational project to charge
PROJECT=project_2000789
# model time step in seconds [does not change]
rn_rdt=2700 # eORCA1/ORCA1
# length of one cycle [year, no-leap]
cycle_length_in_days=365

#####
# no need to change anything below here
run_length=$(( $cycle_length_in_days*24*60*60/$rn_rdt ))

PROJAPPL=/projappl/${PROJECT}
SCRATCH=/scratch/${PROJECT}

NEMOIN=${PROJAPPL}/nemoinput/${HGRID}
NEMOFORCE=${SCRATCH}/nemoforcing/${FORCE}
E0DIR=${SCRATCH}/${USER}/nemo4.0.6/cfgs/${CONF}/EXP00
EDIR=${SCRATCH}/${USER}/nemo4.0.6/cfgs/${CONF}/${ENAME}

init_cycle() {
    cycstr=`printf "%03d" $1`
    mkdir -p ${EDIR}/$cycstr
    cd ${EDIR}/$cycstr

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

    cp -pf $PROJAPPL/$USER/nemoatpuhti/namelist_cfg.${HGRID}.${FORCE} namelist_cfg
    cp -pf $PROJAPPL/$USER/nemoatpuhti/namelist_ice_cfg.orig namelist_ice_cfg
#    cp -pf ${E0DIR}/namelist_ice_cfg .
}

write_cycle_runscript() {
    cycstr=`printf "%03d" $1`
    cd ${EDIR}/$cycstr
    cat << EOF > nemorun.sh
#!/bin/bash -l
#SBATCH --job-name=o1_$cycstr
#SBATCH --account=project_2000789
#SBATCH --mem-per-cpu=2G
#SBATCH -t 12:00:00
#SBATCH -n 36
#SBATCH -p small

module purge
module load StdEnv intel/19.0.4 intel-mpi/18.0.5
module load hdf5/1.10.4-mpi netcdf-fortran/4.4.4 netcdf/4.7.0 

srun ./nemo
EOF
}

#####
#prepare the first cycle (cold or restart)
ncycle=1
cycstr=`printf "%03d" $ncycle`
init_cycle $ncycle
cd ${EDIR}/${cycstr}
echo "                               0  0.0000000000000000E+00  0.0000000000000000E+00" > EMPave_old.dat
# last time step of the previous cycle
np_itend=$(( ($ncycle - 1)*$run_length ))
# first time step for this cycle
nn_it000=$(( ($ncycle - 1)*$run_length + 1 ))
# last time step of this cycle
nn_itend=$(( $ncycle*$run_length ))
# restart file
cn_ocerst_in=${cn_exp}_`printf "%08d" $np_itend`_restart
# add ice restart file
cn_icerst_in=${cn_exp}_`printf "%08d" $np_itend`_restart_ice
# edit namelist_cfg
sed -i  "s|^.* cn_exp.* =.*$|   cn_exp     = "\""$cn_exp"\"" |g" namelist_cfg
sed -i "s|^.* ln_rstart.* =.*$|   ln_rstart   =  .false. |g" namelist_cfg
#sed -i  "s|^.* cn_ocerst_in.*=.*$|   cn_ocerst_in= "\""$cn_ocerst_in"\"" |g" namelist_cfg
#sed -i  "s|^.* cn_icerst_in.*=.*$|   cn_icerst_in= "\""$cn_icerst_in"\"" |g" namelist_ice_cfg
sed -i  "s|^.* nn_it000.* =.*$|   nn_it000    = $nn_it000  |g" namelist_cfg
sed -i  "s|^.* nn_itend.* =.*$|   nn_itend    = $nn_itend  |g" namelist_cfg
sed -i  "s|^.* nn_date0.* =.*$|   nn_date0    = $nn_date0  |g" namelist_cfg
sed -i  "s|^.* nn_stock.* =.*$|   nn_stock    = $run_length  |g" namelist_cfg
write_cycle_runscript $ncycle
cd ${EDIR}/${cycstr}
jobid=`sbatch --parsable nemorun.sh`
pcycstr=${cycstr}

# loop the remaining years here (restarts from the previous year)
for ncycle in $(seq 2 $ncycles);
do
    init_cycle ${ncycle}
    cycstr=`printf "%03d" $ncycle`
    cd ${EDIR}/${cycstr}
    ln -sf ../${pcycstr}/EMPave.dat EMPave_old.dat
    # last time step of the previous cycle
    np_itend=$(( ($ncycle - 1)*$run_length ))
    # first time step for this cycle
    nn_it000=$(( ($ncycle - 1)*$run_length + 1 ))
    # last time step of this cycle
    nn_itend=$(( $ncycle*$run_length ))
    # restart file
    cn_ocerst_in=../${pcycstr}/${cn_exp}_`printf "%08d" $np_itend`_restart
    # add ice restart file
    cn_icerst_in=../${pcycstr}/${cn_exp}_`printf "%08d" $np_itend`_restart_ice
    # edit namelist_cfg
    sed -i  "s|^.* cn_exp.* =.*$|   cn_exp     = "\""$cn_exp"\"" |g" namelist_cfg
    sed -i "s|^.* ln_rstart.* =.*$|   ln_rstart   =  .true. |g" namelist_cfg
    sed -i  "s|^.* cn_ocerst_in.*=.*$|   cn_ocerst_in= "\""$cn_ocerst_in"\"" |g" namelist_cfg
    sed -i  "s|^.* cn_icerst_in.*=.*$|   cn_icerst_in= "\""$cn_icerst_in"\"" |g" namelist_ice_cfg
    sed -i  "s|^.* nn_it000.* =.*$|   nn_it000    = $nn_it000  |g" namelist_cfg
    sed -i  "s|^.* nn_itend.* =.*$|   nn_itend    = $nn_itend  |g" namelist_cfg
    sed -i  "s|^.* nn_date0.* =.*$|   nn_date0    = $nn_date0  |g" namelist_cfg
    sed -i  "s|^.* nn_stock.* =.*$|   nn_stock    = $run_length  |g" namelist_cfg
    write_cycle_runscript ${ncycle}
    cycstr=`printf "%03d" $ncycle`
    cd ${EDIR}/${cycstr}
    jobid=`sbatch --dependency=afterok:$jobid --parsable nemorun.sh`
    pcycstr=${cycstr}
done

