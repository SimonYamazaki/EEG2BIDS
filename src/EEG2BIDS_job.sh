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
    -a|--anaconda)
      anaconda_path="$2"
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

if [[ -z ${anaconda_path} ]]; then
echo "no anaconda path was given, defaulting to /home/simonyj/anaconda3. Add the --anaconda argument to specify another anaconda path."
anaconda_path="/home/simonyj/anaconda3"
fi

toolbox_folder=$(pwd)

echo ${toolbox_folder}

script_folder=$(dirname "$script2exe")
script_name_and_ext=$(basename "$script2exe")
arr=(${script_name_and_ext//./ })
script2exe_wo_ext=${arr[0]}


if [[ -z "${sess}" && -z "${subj}" ]]; then
echo "Running BIDS dataset for multiple subjects or sessions"
echo "Running ${script2exe}.m"
matlab_command="${script2exe_wo_ext}('${BIDS_dir}')"
out_file_path="${BIDS_dir}/cluster_submissions/slurm-${SLURM_JOB_ID}-${script2exe_wo_ext}-${ts}.txt"

elif [[ -z "${subj}" || -z "${sess}" ]];
then
echo "Running BIDS dataset for subject "${subj}" but without any session"
matlab_command="${script2exe_wo_ext}('${BIDS_dir}','${subj}')"
out_file_path="${BIDS_dir}/cluster_submissions/slurm-${SLURM_JOB_ID}-${script2exe_wo_ext}-${ts}-${subj}.txt"

else
echo "Running BIDS dataset for subject "${subj}" in session "${sess}""
matlab_command="${script2exe_wo_ext}('${BIDS_dir}','${subj}','${sess}')"
out_file_path="${BIDS_dir}/cluster_submissions/slurm-${SLURM_JOB_ID}-${script2exe_wo_ext}-${ts}-${subj}-${sess}.txt"
fi

cd ${script_folder}

echo "Running ${script2exe}"
/mnt/depot64/matlab/R2020a/bin/matlab -nodesktop -nojvm -nosplash -r "${matlab_command}"

cd ${toolbox_folder}
#source ${anaconda_path}/bin/activate
#python change_json_int_keys.py $BIDS_dir

echo
echo "#####  BIDS VALIDATION OUTPUT  #####"
echo
module load nodejs
/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir >> "${out_file_path}"



#/mnt/projects/VIA11/EEG/BIDS_validator/node_modules/bids-validator/bin/bids-validator $BIDS_dir --json > $BIDS_dir/BIDS_validation.json 


