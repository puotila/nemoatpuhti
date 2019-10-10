#!/bin/bash -l
###
### parallel job script example
###
## name of your job
#SBATCH --job-name=o025
#SBATCH --account=project_2000789
#SBATCH --time=02:00:00
#SBATCH --mem-per-cpu=2G
#SBATCH --ntasks=128
#SBATCH --partition=large

module purge
module load StdEnv intel/19.0.4 intel-mpi/18.0.5
module load hdf5/1.10.4-mpi netcdf-fortran/4.4.4 netcdf/4.7.0 

module list
date

# experiment name [does not change]
cn_exp="ORCA025.L75"
# time step in seconds [does not change]
rn_rdt=900
# length of one cycle [year, no-leap]
run_length_in_days=10
run_length=$(( $run_length_in_days*24*60*60/$rn_rdt ))
# how many cycles to run 
ncycles=2

# how many cycles have already been completed? 
# Indicated by how many ocean.output.${ncycle} files we have
for n in `seq $ncycles -1 1`
do
    if [ -f ocean.output.$n ]; then 
	    break
    fi
    ncycle=$n
done

# Everything has been done already
if [ "$ncycles" -eq "$ncycle" ]; then
    echo "All cycles have been completed."
    exit 0
fi

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

# copy and modify namelist(s) for the next cycle
cp -p namelist_cfg.orig namelist_cfg
cp -p namelist_ice_cfg.orig namelist_ice_cfg
if [ -f EMPave.dat ]; then 
    cp -p EMPave.dat EMPave_old.dat
else
    echo "                               0  0.0000000000000000E+00  0.0000000000000000E+00" > EMPave_old.dat
fi
if [ "$ncycle" -eq 1 ]; then
    sed -i "s|^.* nn_rstctl.* =.*$|   nn_rstctl   =  0 |g" namelist_cfg
    # change ln_restart = .false. if cold start (i.e no rst_in files)
    sed -i "s|^.* ln_rstart.* =.*$|   ln_rstart   =  .true. |g" namelist_cfg
else
    sed -i "s|^.* nn_rstctl.* =.*$|   nn_rstctl   =  2 |g" namelist_cfg
    sed -i "s|^.* ln_rstart.* =.*$|   ln_rstart   =  .true. |g" namelist_cfg
fi
sed -i  "s|^.* cn_exp.* =.*$|   cn_exp     = "\""$cn_exp"\"" |g" namelist_cfg
sed -i  "s|^.* cn_ocerst_in.*=.*$|   cn_ocerst_in= "\""$cn_ocerst_in"\"" |g" namelist_cfg
sed -i  "s|^.* cn_icerst_in.*=.*$|   cn_icerst_in= "\""$cn_icerst_in"\"" |g" namelist_ice_cfg
sed -i  "s|^.* nn_it000.* =.*$|   nn_it000    = $nn_it000  |g" namelist_cfg
sed -i  "s|^.* nn_itend.* =.*$|   nn_itend    = $nn_itend  |g" namelist_cfg
sed -i    "s|^.* rn_rdt.* =.*$|   rn_rdt      = $rn_rdt  |g" namelist_cfg

# run model 
srun ./nemo.exe

# check if NEMO run ended fine from ocean.output
# if not then exit noisily
if [ -f ${cn_ocerst_in}_0000.nc ]
then
    echo "Leg successfully completed according to NEMO log file 'ocean.output'."
else
    echo "NEMO restart files ${cn_ocerst_in}_0000.nc not found after run."
fi

# save output and configuration files of this cycle
mv ocean.output ocean.output.${ncycle}
cp -p namelist_cfg namelist_cfg.$ncycle
# submit the next cycle
sbatch --dependency=afterok:$SLURM_JOB_ID ./nemo4_run_orca025_puhti.sh
###
