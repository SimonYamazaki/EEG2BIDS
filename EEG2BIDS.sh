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

if [[ -z "${sess}" && -z "${subj}" ]]; then
echo "Running BIDS dataset without any specific subject or session"
sbatch --output="${BIDS_dir}/cluster_submissions/slurm-%j-${ts}.txt" "EEG2BIDS_job.sh" --bids_dir ${BIDS_dir} --datetime ${ts} --script ${script2exe}

elif [[ -z "${subj}" || -z "${sess}" ]];
then
echo "Running BIDS dataset for subject "${subj}" but without any session"
sbatch --output="${BIDS_dir}/cluster_submissions/slurm-%j-${ts}-${subj}.txt" "EEG2BIDS_job.sh" --bids_dir ${BIDS_dir} --datetime ${ts} --subject ${subj} --script ${script2exe}

else
echo "Running BIDS dataset for subject "${subj}" in session "${sess}""
sbatch --output="${BIDS_dir}/cluster_submissions/slurm-%j-${ts}-${subj}-${ses}.txt" "EEG2BIDS_job.sh" --bids_dir ${BIDS_dir} --datetime ${ts} --subject ${subj} --session ${ses} --script ${script2exe}
fi


#example: bash EEG2BIDS.sh --bids_dir /home/simonyj/EEG_BIDS_MMN --script EEG2BIDS_MMN


