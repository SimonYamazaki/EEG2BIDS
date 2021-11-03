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


if [[ -z ${BIDS_dir} ]]; then
echo "bids_dir argument is missing. Add the --bids_dir argument."
exit 1
elif [ -z ${script2exe} ]; then
echo "The EEG2BIDS matlab script argument is missing. Add the --script argument"
exit 1
fi

mkdir -p ${BIDS_dir}
mkdir -p "${BIDS_dir}/cluster_submissions"

ts=$(date +%FT%T)

script_name_and_ext=$(basename "$script2exe")
arr=(${script_name_and_ext//./ })
script2exe_wo_ext=${arr[0]}


if [[ -z "${sess}" && -z "${subj}" ]]; then
echo "Running BIDS dataset for multiple subjects or sessions"
sbatch --output="${BIDS_dir}/cluster_submissions/slurm-%j-${script2exe_wo_ext}-${ts}.txt" "EEG2BIDS_job.sh" --bids_dir ${BIDS_dir} --datetime ${ts} --script ${script2exe} --anaconda ${anaconda_path}

elif [[ -z "${subj}" || -z "${sess}" ]];
then
echo "Running BIDS dataset for subject "${subj}" but without any session"
sbatch --output="${BIDS_dir}/cluster_submissions/slurm-%j-${script2exe_wo_ext}-${ts}-${subj}.txt" "EEG2BIDS_job.sh" --bids_dir ${BIDS_dir} --datetime ${ts} --subject ${subj} --script ${script2exe} --anaconda ${anaconda_path}

else
echo "Running BIDS dataset for subject "${subj}" in session "${sess}""
sbatch --output="${BIDS_dir}/cluster_submissions/slurm-%j-${script2exe_wo_ext}-${ts}-${subj}-${sess}.txt" "EEG2BIDS_job.sh" --bids_dir ${BIDS_dir} --datetime ${ts} --subject ${subj} --session ${sess} --script ${script2exe} --anaconda ${anaconda_path}
fi

