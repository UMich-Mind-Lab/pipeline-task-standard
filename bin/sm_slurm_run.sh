#!/bin/bash

# LOAD MODULES
module load python3.7-anaconda/2020.02 singularity matlab/R2019b fsl/6.0.3

# ACTIVATE CONDA ENVIRONMENT
eval "$(conda shell.bash hook)"
conda activate ../../lib/.conda/snakemake

# COPY SLURM PROFILE TO RELEVANT DIRECTORY
#mkdir -p ~/.config/snakemake/
#cp -vur .config/snakemake/ ~/.config/snakemake/

pwd
# RUN SNAKEMAKE
snakemake -s snakefile --cluster "sbatch -A {cluster.account} \
  -p {cluster.partition} --mail-type={cluster.mail-type} --time={cluster.time} \
  -N {cluster.nodes} --ntasks-per-node={cluster.ntasks-per-node} \
  --cpus-per-task={cluster.cpus-per-task} --mem={cluster.mem} \
  --job-name={cluster.job-name} -o {cluster.out} -e {cluster.err}" \
  --cluster-config config/sm_slurm-config.json -k --jobs 150 --latency-wait 90 --rerun-incomplete

# I don't understand profiles but maybe I'll figure it out later
# snakemake -s ./snakefiles/func_processing_test.smk --profile slurm-func \#
#   --jobs 10 --latency-wait 10

# CLEAN OUTPUT FILES

#get log output directory from cluster config file
outDir=$(cat ./config/sm_slurm-config.json | python3 -c "import sys,json; print(json.load(sys.stdin)['__default__']['out'])")
outDir=$(dirname ${outDir})
for logFile in "${outDir}"/*; do
  [ -f ${logFile} ] || continue
  logFile=$(basename ${logFile})
  #separate log filename into array of parts (delimiter = "_"). Each part will be
  #made into a folder leaving the final part as the base filename
  logParts=(${logFile//_/ }) #split filename by space delimiter into bash array
  baseFileName=${logParts[-1]} #extract final element of array
  unset 'logParts[${#logParts[@]}-1]' #remove final element from array
  logParts=$(echo ${logParts[*]}) #reattach array as single bash string
  logParts=${logParts// /"/"}  #replace space delimiter with /

  mkdir -p "${outDir}/${logParts}"
  mv "${outDir}/${logFile}" "${outDir}/${logParts}/${baseFileName}"
done
