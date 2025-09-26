#!/usr/bin/env zsh
#SBATCH --partition=instruction 
#SBATCH --time=00:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --output=parallel_sum.output

cd $SLURM_SUBMIT_DIR
g++ -fopenmp parallel_sum.cpp -o parallel_sum 
./parallel_sum