#!/bin/bash

# ACTIVATE CONDA ENVIRONMENT
eval "$(conda shell.bash hook)"
conda activate ../../lib/.conda/snakemake

# RUN SNAKEMAKE
snakemake -s snakefile -k -j 10
