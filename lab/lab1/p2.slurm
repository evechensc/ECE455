#!/usr/bin/env zsh
#SBATCH --partition=instruction 
#SBATCH --time=00:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --output=compile_run.output

cd $SLURM_SUBMIT_DIR 
module load gcc/13.2.0 
g++ main.cpp -o main 
./main