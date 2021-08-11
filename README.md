## EEG2BIDS
#How to make a BIDS compliant EEG dataset

1. Make a EEG2BIDS_*YOUR-TASK*.m file 
2. Make a EEG_*YOUR-TASK*_job.sh file 
3. (If any source data or derivative data should be added to the BIDS directory) make a EEG2BIDS_*YOUR-TASK*_derivatives.m or EEG2BIDS_*YOUR-TASK*_sourcedata.m file.

Look at already existing files for the flanker-task and the MMN-task for inspiration.

If nothing is outputted from your matlab script in the .out file, debug by running the matlab script isolated. E.g. run your function in the matlab command window without input arguments "EEG2BIDS_flanker()" or "EEG2BIDS_flanker("009","via11")"
