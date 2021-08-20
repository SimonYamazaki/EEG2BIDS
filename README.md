## EEG2BIDS
#How to make a BIDS compliant EEG dataset
1. Clone this repository and a modified version of the fieldtrip repository from [here](https://github.com/SimonYamazaki/fieldtrip)

2. Make a ```EEG2BIDS_*YOUR-TASK*.m``` file as a matlab function. Look at already existing files for the ASSR-reg-task and the MMN-task for examples. A few files are loaded by these examples scripts which includes: 
	```*YOUR-TASK*_events.txt```
	```*YOUR-TASK*_instructions.txt```
	```participants_variables.txt```
These files must follow the exact format of the examples in this repository to be loaded correctly. If files follow another format the loading procedure of such files must be changed in the ```EEG2BIDS_*YOUR-TASK*.m``` script. 

3. In a terminal run the following code: 
```
bash EEG2BIDS.sh --bids_dir /path/to/bids_dir --script name_of_script_without_matlab_extension
```
If the ```EEG2BIDS_*YOUR-TASK*.m``` file is made in a similar manner to the examples given in this repository, single subjects can be run by specifying a subject and a session argument. Example:
```
bash EEG2BIDS.sh --bids_dir /path/to/bids_dir --script name_of_script_without_matlab_extension --subject 001 --session via11
```
By default the output of the BIDS directory creation is put into a .txt file located in the ```/cluster_submission``` directory in the BIDS directory. The name of this output file follows the following scheme: 
```
slurm-SLURM_ID-YY-MM-DDT-HH:MM:SS.txt
```
If a single subject is run the subject ID is appended as so:
```
slurm-SLURM_ID-YY-MM-DDT-HH:MM:SS-SUBJECT_ID.txt
```

(4). If any source data or derivative data should be added to the BIDS directory make a ```EEG2BIDS_*YOUR-TASK*_derivatives.m``` or ```EEG2BIDS_*YOUR-TASK*_sourcedata.m``` file.

If nothing is outputted from your matlab script in the .out file, debug by running the matlab script isolated in matlab. E.g. run your function in the matlab command window without input arguments ```EEG2BIDS_flanker()``` or with input arguments ```EEG2BIDS_flanker("009","via11")```
