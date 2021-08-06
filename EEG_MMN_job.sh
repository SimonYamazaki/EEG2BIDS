#!/bin/bash
#SBATCH --partition=HPC
DISPLAY=

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -b|--bids_dir)
      BIDS_dir="$2"
      shift # past argument
      shift # past value
      ;;
    -sub|--subject)
      subj="$2"
      shift # past argument
      shift # past value
      ;;
    --default)
      DEFAULT=YES
      shift # past argument
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters



/mnt/depot64/matlab/R2020a/bin/matlab -nodesktop -nojvm -nosplash -r "EEG2BIDS_MMN"

source $HOME/anaconda3/bin/activate

python change_json_int_keys.py

module load nodejs

/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir --json > $BIDS_dir/BIDS_validation.json 

/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir > $BIDS_dir/BIDS_validation.txt

