#!/bin/bash
#SBATCH --job-name HPL_ParamSweep
#SBATCH --partition general
#SBATCH --time 00:10:00
#SBATCH --nodes 10
#SBATCH --ntasks-per-node 16
#SBATCH --mem 0
#SBATCH --array 1-4

# Load the required packages (gcc 11 and HPL)
module load gcc/11.2.0-655h hpl
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores
export OMP_NUM_THREADS=4

# Set a place to record the results
RESULTS_FILE=$SLURM_SUBMIT_DIR/HPL_results.csv
PARAMS_FILE=$SLURM_SUBMIT_DIR/HPL_params.csv
TEMPLATE_FILE=$SLURM_SUBMIT_DIR/HPL_template.dat

# Check for errors
if test -f $PARAMS_FILE; then
    echo Using parameter file $PARAMS_FILE
else
    echo Error $PARAMS_FILE not found
    exit 1
fi

if test -f $TEMPLATE_FILE; then
    echo Using template file $TEMPLATE_FILE
else
    echo Error $TEMPLATE_FILE not found
    exit 2
fi
    
# Get the Nth line from our parameter file - where N is the array ID
PARAMS=$(head -n $SLURM_ARRAY_TASK_ID $PARAMS_FILE | tail -n 1)
echo Read param line $SLURM_ARRAY_TASK_ID: $PARAMS

# Get both parameters from the line (comma separated)
BLOCK_SIZE=$(echo $PARAMS | awk -F"," '{print $1}')
PROBLEM_SIZE=$(echo $PARAMS | awk -F"," '{print $2}')
echo Read param BLOCK_SIZE: $BLOCK_SIZE
echo Read param PROBLEM_SIZE: $PROBLEM_SIZE

# Create a new working directory
SCRATCH_DIR=/carc/scratch/users/$USER
TMP_DIR=$(mktemp --directory -p $SCRATCH_DIR)
echo Temp directory: $TMP_DIR

# Make a subdirectory with the SLURM array task id
TMP_WORKING_DIR=$TMP_DIR/$SLURM_ARRAY_TASK_ID
mkdir -p $TMP_WORKING_DIR
echo Created temporary working directory: $TMP_WORKING_DIR

# Make the new working directory the current directory
cd $TMP_WORKING_DIR
echo Now running in $PWD

# Copy and modify the template file
cp $TEMPLATE_FILE $TMP_WORKING_DIR/HPL.dat

# Substitute both parameters
sed -i "s/<BLOCK_SIZE>/$BLOCK_SIZE/g" HPL.dat
sed -i "s/<PROBLEM_SIZE>/$PROBLEM_SIZE/g" HPL.dat

echo Running xhpl in $TMP_WORKING_DIR...
srun --mpi=pmi2 xhpl
echo xhpl finished

# Extract results
RESULT_HEADER_AND_DATA_LINES=$(grep --after 2 Gflops HPL.out)
echo Results: $RESULT_HEADER_AND_DATA_LINES

RESULT_DATA_LINE=$(echo $RESULT_HEADER_AND_DATA_LINES | tail -n 1)
echo Results data: $RESULT_DATA_LINE

GFLOPS=$(echo $RESULT_DATA_LINE | awk -F" " '{print $NF}')
echo Results Gflops: $GFLOPS 

# Save results with both parameters
echo $BLOCK_SIZE, $PROBLEM_SIZE, $GFLOPS >> $RESULTS_FILE

# Clean up
rm -r $TMP_DIR
echo Deleted $TMP_DIR
