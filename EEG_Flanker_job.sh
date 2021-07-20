#!/bin/bash
#SBATCH --partition=HPC
DISPLAY=

/mnt/depot64/matlab/R2020a/bin/matlab -nodesktop -nojvm -nosplash -r "EEG2BIDS_flanker"

source $HOME/anaconda3/bin/activate

python change_json_int_keys.py
python BIDS_validator_EEG.py

