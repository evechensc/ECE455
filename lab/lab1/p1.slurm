#!/user/bin/env zsh 

#SBATCH --partition=instruction 
#SBATCH --time=00:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1 
#SBATCH --output=hello.output

cd $SLURM_SUBMIT_DIR
echo "Hello from node $(hostname)"