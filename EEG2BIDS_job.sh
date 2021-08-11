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
    -sc|--script)
      script2exe="$2"
      shift # past argument
      shift # past value
      ;;
    -sub|--subject)
      subj="$2"
      shift # past argument
      shift # past value
      ;;
    -ses|--session)
      sess="$2"
      shift # past argument
      shift # past value
      ;;
    -ts|--datetime)
      ts="$2"
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


if [[ -z "${sess}" && -z "${subj}" ]]; then
echo "Running BIDS dataset without any specific subject or session"
/mnt/depot64/matlab/R2020a/bin/matlab -nodesktop -nojvm -nosplash -r "${script2exe}()"
source $HOME/anaconda3/bin/activate
python change_json_int_keys.py
echo
echo "#####  BIDS VALIDATION OUTPUT  #####"
echo
module load nodejs
/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir >> "${BIDS_dir}/cluster_submissions/slurm-${SLURM_JOB_ID}-${ts}.txt"

elif [[ -z "${subj}" || -z "${sess}" ]];
then
echo "Running BIDS dataset for subject "${subj}" but without any session"
/mnt/depot64/matlab/R2020a/bin/matlab -nodesktop -nojvm -nosplash -r "${script2exe}(${subj})"
source $HOME/anaconda3/bin/activate
python change_json_int_keys.py
echo
echo "#####  BIDS VALIDATION OUTPUT  #####"
echo
module load nodejs
/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir >> "${BIDS_dir}/cluster_submissions/slurm-${SLURM_JOB_ID}-${ts}-${subj}.txt"

else
echo "Running BIDS dataset for subject "${subj}" in session "${sess}""
/mnt/depot64/matlab/R2020a/bin/matlab -nodesktop -nojvm -nosplash -r "${script2exe}(${subj},${sess})"
source $HOME/anaconda3/bin/activate
python change_json_int_keys.py
echo
echo "#####  BIDS VALIDATION OUTPUT  #####"
echo
module load nodejs
/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir >> "${BIDS_dir}/cluster_submissions/slurm-${SLURM_JOB_ID}-${ts}-${subj}-${sess}.txt"
fi


#/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir --json > $BIDS_dir/BIDS_validation.json 


