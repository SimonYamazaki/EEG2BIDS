# EEG2BIDS

Notes:
- only works for files that can be read by fieldtrip. Currently only tested for .bdf files.
- assumes access to a slurm batch system with the command ```sbatch```
- if you dont have access to ```sbatch``` simply run your task script ```EEG2BIDS_*YOUR-TASK*.m``` in terminal or in matlab console (with proper input arguments). Look at ```/Examples``` for examples of such scripts.
- ensures bids version 1.6 compliance
- ```EEG2BIDS_template.m``` is not up to date either
- for any questions write an email - simonyj@drcmr.dk


## How to make a BIDS compliant EEG dataset

1. Clone this repository and a modified version of the fieldtrip repository from [here](https://github.com/SimonYamazaki/fieldtrip). Remember to add the paths of these repositories in your matlab scripts.

2. Make a ```EEG2BIDS_*YOUR-TASK*.m``` file as a matlab function. Look at already existing files in ```/Examples``` for the ASSR-reg-task and the MMN-task examples. The examples include comprehensive comments about how to make the scripts, thus go through each line that seems appropriate for your dataset. A few files are loaded by these examples scripts which includes:
	```*YOUR-TASK*_events.txt```,
	```*YOUR-TASK*_instructions.txt```,
	```participants_variables.txt```
These files must follow the exact format as seen in ```/Examples/example_files``` in this repository to be loaded correctly by functions in ```/utils```. If files follow another format the loading procedure of such files must be changed in the ```EEG2BIDS_*YOUR-TASK*.m``` script. If integer json file fields are desired, name the field ```Int_1``` for the integer field ```1``` in your matlab script. The python script ```/src/change_json_int_keys.py``` will remove the ```'Int_'``` part which leaves only the integer.


3. In a terminal run the following line from ```/src``` folder:
```
bash EEG2BIDS.sh --bids_dir /path/to/bids_dir --script path/to/matlab/script.m
```
This command will make the bids_dir for all subjects and files specified in your matlab script. The bids_dir will be created if it does not already exist. It is assumed that the bids_dir created with this method is a ```/rawdata``` directory. Thus if the root directory generated by this method should be located where an already created sourcedata directory exists, the bids_dir should be something like ```/path/to/sourcedata/parent/directory/rawdata```. If the ```EEG2BIDS_*YOUR-TASK*.m``` file is made in a similar manner to the examples given in this repository, single subjects can be run by specifying a subject and a session argument. Here is an example:

```
bash EEG2BIDS.sh --bids_dir /path/to/bids_dir --script path/to/matlab/script.m --subject 001 --session via11
```

By default the output of the BIDS directory creation is put into a .txt file located in the ```/cluster_submission``` directory in the BIDS directory. The name of this output file follows the following scheme:
```
slurm-{SLURM_JOB_ID}-{TASK_SCRIPT_NAME}-YY-MM-DDT-HH:MM:SS.txt
```
If a single subject is run the subject ID is appended as so:
```
slurm-{SLURM_JOB_ID}-{TASK_SCRIPT_NAME}-YY-MM-DDT-HH:MM:SS-{SUBJECT_ID}.txt
```

In case you have multiple tasks / paradigms that you want in one bids_dir, make a ```EEG2BIDS_*YOUR-TASK*.m``` for each task, and run them sequentially with the same bids_dir. The init.dataset_description information is only needed in the first task script.

If nothing is outputted from your matlab script in the slurm output .txt file in ```/cluster_submission```, debug by running the matlab script isolated in matlab. E.g. run the function in your script in the matlab command window without any specific subject ```EEG2BIDS_flanker('/path/to/bids_dir')``` or for a specific subject ```EEG2BIDS_flanker('/path/to/bids_dir',"009","via11")```. This way of running the file is also a way to circumvent the need of sbatch/slurm.

(4). If any source data or derivative data should be added to the BIDS directory make a ```EEG2BIDS_*YOUR-TASK*_derivatives.m``` or ```EEG2BIDS_*YOUR-TASK*_sourcedata.m``` file. See examples in ```/Examples```.


## How to manually write a json file in your script
