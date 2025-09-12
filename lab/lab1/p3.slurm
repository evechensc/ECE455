#!/usr/bin/env zsh
#SBATCH --partition=instruction 
#SBATCH --time=00:02:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=multicpu.output

cd $SLURM_SUBMIT_DIR
module load gcc/13.2.0
g++ -std=c++17 parallel.cpp -o parallel -pthread 
./parallel