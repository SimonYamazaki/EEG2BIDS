function EEG2BIDS_flanker_sourcedata(varargin)
%The first input to function is the bids_dir, that is the name of the 
%new directory that will be made
%If this dataset should be included in an already existing
%bids_dir then simply use this function with the same bids_dir

% This function takes up to 3 inputs: '{bids_dir}','{subject id}','{session}'
%only the first argument is mandatory


%% Setup  
% CHANGES NEEDED IN THIS SECTION

%General comments
% - Comment/remove lines in this section that are not needed if OPTIONAL
% - Search patterns are given as inputs to MATLAB function "dir", i.e use asterisk
% - Go through each section in this script with "CHANGES NEEDED IN THIS SECTION" 
%and make changes appropriate for your dataset
% - if in doubt about a spefific files and fields in json files refer to
% the specification at https://bids.neuroimaging.io/specification.html

%Path to the cloned EEG2BIDS dir from https://github.com/SimonYamazaki/EEG2BIDS
init.EEG2BIDS_tool_dir = '/mnt/projects/VIA11/EEG/BIDS_creation_files/EEG2BIDS';
addpath(fullfile(init.EEG2BIDS_tool_dir,'utils'))

%Path to the cloned fieldtrip dir from https://github.com/SimonYamazaki/fieldtrip
%Note: you will not be able to use your own installation of fieldtrip as
%the file data2bids.m in the fieldtrip package has been modified. If you
%insist to use your own fieldtrip installation, replace the existing
%data2bids.m file with the one from https://github.com/SimonYamazaki/fieldtrip
init.fieldtrip_dir = '/mnt/projects/VIA11/EEG/BIDS_creation_files/fieldtrip';

%The name of the bids dataset
% - name of your BIDS dataset to go into the dataset_description.json
% - this is different that bids_dir, which is a path to your BIDS folder
% - for multiple tasks in one bids_dir this name should be identical
init.bids_dataset_name = 'VIA11_EEG_BIDS';

%The task name
% - The task that this script concerns
% - Each task has a unique label that MUST only consist of letters and/or 
%numbers. Other characters, including spaces and underscores, are not allowed
init.task = 'Flanker';


%Specify data directories
% - If session folders should be created in the bids dataset, data_dir should
%be a struct with the fieldnames corresponding to the session names
% - If no sessions are needed let data_dir be a character array with the
%path to the data_dir
% - If data is not located in the same folder or the subject ids cannot be 
%extracted from file names refer to "Manually specifying data files" below 
%and comment/remove definitions of init.data_dir, init.data_file, 
%init.nono_keywords_in_filename, init.id_search_method and init.id_trans
init.data_dir.via11 = '/mnt/projects/VIA11/EEG/Data/###_Flanker';
%init.data_dir.via15 = '/home/simonyj/EEG_MMN';
init.bids_dir = char(varargin{1}); %dont change this! bids_dir is parsed as the first input in the function 

%Search pattern for data files in data_dir
% - data_file follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - searches data_dir for data_file
init.data_file.via11 = 'flanker_kids_eegBackup_new-*-1.txt';
%'flanker_kids_eegBackup_new-%s-1.edat2';

%Keywords in the data_file name that should not be present
% - OPTIONAL
% - if this keyword is found, the file will not be moved to BIDS dataset
% - this functionality looks for any substring, thus careful you dont
% substring something that you want, i.e. if you want ASSR_irreg.bdf files,
%and dont want ASSR_reg.bdf, dont just write 'reg' below, instead do '_reg'
%init.nono_keywords_in_filename = {'ASSR','MMN'};


%Specify method to extract subject id from file name
% - assumes that the subject ids to include in the bids dataset can be 
%extracted from data_file names
% - if the subject id can not be extracted from the file name, refer to 
%"Manually specifying data files" below
% - the format of the ids extracted from the filename will be the format
%used for subject ids throughout the bids dataset 
% - if the format needs a transformation refer to the "Define a transformation
%from the extracted ids" below
% - id_search_method must be a cell array with 'manual' or 'auto' as the first element
% - the 'auto' method will use an automatic id detection 
% - if the 'manual' method is specified, the second element in the cell array
%of id_search_method should be a double array with character indexes for the  
%subject id in the file name string - from the whole file name string and not 
% data_file. Assumes that subject ids is extracted from the same character indexes 
%in all files. Note: the file name string is not an input here but found
%from the data_file names. If this method is not applicable for you,
%instead refer to the "Manually specifying data files" below.
%example: init.id_search_method = {'manual',1:3}; will extract '009' from filename 009_mmn.bdf
init.id_from_data_file_folder = false;
init.id_search_method = {'auto'};

%Define a transformation of the extracted ids 
% - OPTIONAL
% - if the id extracted from the file name is not the desired id format 
%define a transformation as a function handle below
init.id_trans = @(x) sprintf('%03s',x); %transforms '9' to '009' and '34' to '034' while also transforming '009' to '009'

%Particular subjects to remove
% - OPTIONAL
% - Specify subjects that should be excluded. Remember to add a note
% somewhere, e.g. in README.
%init.exclude.via11 = {'065'};

%Manually specifying data files
% - OPTIONAL
% - if subject ids cant be extracted from data_file, add IDs and the
%corresponding file paths here. 
% - init.sub and init.sub_files should have same length, that is each file
%path must have a corresponding id. For mulitple files from one subject repeat 
%the subject id. 
% - the format of IDs defined here will be the ID format in your bids_dir
% - Do not define these structs if data_dir and data_file is defined
%init.sub.via11 = {'009'  '146'  '302'};
%init.sub_files.via11 = {'/path/to/file1.bdf','/path/to/file2.bdf','/path/to/file3.bdf'};
%init.sub.via15 = {'009'  '146'  '302'};
%init.sub_files.via15 = {'/path/to/file1.bdf','/path/to/file2.bdf','/path/to/file3.bdf'};

%Parse a subject info table from database for participant information.
% - info goes into participants.tsv
% - assumes the table has a column of subject ids, and rows consisting of 
%participant info for a particular subject id 
% - assumes that participant info is identical for all tasks in bids_dir
init.sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
init.sub_info_table = readtable(init.sub_info_table_path); %read the table

%Get subject ids coloum from sub_info_table. 
% - each element in the coloumn must be a unique identifier of a subject
% - remember to add a transformation to the same format as the extracted 
%subject ids or the ids specified in "manually specifying data files" if
%the format of subject ids are different in the table
% - participant_id_trans is not needed if the coloumn in sub_info_table is
%already encoded in the right way
init.IDs = init.sub_info_table.('famlbnr'); %this column of ids are double precision integers
init.participant_id_trans = @(x) sprintf('%03s',num2str(x)); %transforms a double precision integer 9 to '009' and 34 to '034'

%A subject ID prefix to be added for subject folders in bids_dir
% - OPTIONAL
% - for a subject folder with name "sub-via009" the ID_prefix should be 'via'
init.ID_prefix = 'via';

%Search pattern for other files that must exist along the data_file
% - OPTIONAL
% - follows the same structure as data_dir with respect to sessions
% - field names of the structs below must be identical to data_dir field names
% - Must also specify where to find the id corresponding to the must_exist_files
% - EXEPTION: if there are sessions without the need of must_exist_files, then
%simply dont define the field of that session in must_exist_files
init.must_exist_files.via11 = {'/mnt/projects/VIA11/EEG/Data/###_Flanker/flanker_kids_eegBackup_new-*-1.txt'};  %'/home/simonyj/EEG_MMN/**/*_triggers.mat'
%init.must_exist_files.via15 = {'/mrhome/simonyj/nobackup/###_MMN/*_triggers.mat'}; 
init.id_from_folder = false; %false -> extracts id from filename, true -> find it from folder name
init.must_exist_files_id_search = {'manual',28:30}; %from either directory or file name

%Search pattern for files that must exist to determine existing subjects in BIDS directory
% - these files may vary depending on the task and eeg file format,
% however, must be specified!
% - follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - must include all the sessions defined in data_dir
% - files_checked searches for these files in the /eeg folder within each
% subject folder
init.files_checked.via11 = {'????'};
%init.files_checked.via15 = init.files_checked.via11;


%Whether to include a scans.tsv file
init.include_scans_tsv = false;

%whether to include participants.tsv 
%ONLY use this functionality for derivatives or sourcedata
init.include_participants_tsv = false;

%Whether to include events.tsv
% - events MAY be either stimuli presented to the participant or participant responses
% - events.tsv file are generated based on the events field in the bdf 
%file header by default. 
% - refer to the events part of section "Generate BIDS structure and files"
%in this script for any custom changes to this events.tsv file outside the 
%events in the bdf file header
init.include_events_tsv = false; 

%Should events.json be loacted in bids_dir or subject folders
% - if in bids_dir, according to the inheritance principle, the event
%files are general for all subjects and sessions
% - this functionality is needed for mulitple tasks in bids_dir
init.events_in_sub_dir = true; %false -> events.json will be located in bids_dir


%General information to be put into dataset_description.json file
% - dataset_description.json should always be written unless multiple tasks 
%are combined into one bids_dir, then only write it for the first task
init.dataset_description.BIDSVersion = '1.6'; 
init.dataset_description.Name = init.bids_dataset_name;
init.dataset_description.DatasetType = 'source'; 
init.dataset_description.EthicsApprovals = {'The local Ethical Committee (Protocol number: H 16043682)','The Danish Data Protection Agency (IDnumber RHP-2017-003, I-suite no. 05333)'}; % - OPTIONAL

%configure the initialization 
init.varargin = varargin;
input = configure_init(init);

%Note that the variable named 'input' (which is a struct) includes a field 
%called run_mode which has the value 'new_bids' if a new_bids 
%task/session/dataset should be created. Thus, input.run_mode can be used 
%to infer whether general bids files should be written everytime this script
%is run.


%% Generate BIDS structure and files
% CHANGES NEEDED IN THIS SECTION

%%%%%% Use data2bids function on each subject in loop %%%%%%%%

% for more information on data2bids function see: 
% https://github.com/SimonYamazaki/fieldtrip/blob/master/data2bids.m
% which is a modified version of: https://github.com/fieldtrip/fieldtrip/blob/master/data2bids.m

% The RECOMMENDED comment is inputs that are recommended to be filled by
% the bids specification - thus not mandatory.

%loop over sessions and subjects to make bids_dir
for sesindx=1:numel(input.ses)
    for subindx=1:numel(input.sub.(input.ses{sesindx}))
    
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy'; 
    cfg.datatype  = 'events';
    cfg.non_raw_data = true;
    cfg.bids_datatype = 'source';
    
    cfg.sesindx = sesindx;
    cfg.subindx = subindx;
    
    %Configure inputs and add it to the cfg struct. The cfg struct is unique
    %for every iteration in this loop, i.e. for every session and subject
    cfg = configure_input(cfg,input);
    
    %Provide the mnemonic and long description of the task
    cfg.TaskName        = init.task;
    cfg.TaskDescription = '????';

    %%%%%%% MAKING BIDS DATASET FOR THE CURRENT SUBJECT IN LOOP %%%%%%% 
    
    %make bids dataset with the cfg struct
    data2bids(cfg);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    end
end


%% Delete files not needed 

% remove files not needed in the sourcedata directory
%sfile_names = cellstr({ dir(fullfile(sourcedata_dir, '**/*_scans.tsv')).name });
%sfile_dirs = cellstr({ dir(fullfile(sourcedata_dir, '**/*_scans.tsv')).folder });
%sfiles2del = strcat(sfile_dirs,'/',sfile_names);
sfiles2del = cell(0);
%sfiles2del{end+1} = fullfile(sourcedata_dir, '/participants.tsv');
%sfiles2del{end+1} = fullfile(sourcedata_dir, '/dataset_description.json');

for f = 1:length(sfiles2del)
    delete(sfiles2del{f})
end

%% Write a readme and .bidsignore file 
% CHANGES NEEDED IN THIS SECTION
% - RECOMMENDED

if strcmp(input.run_mode,'new_BIDS')
    %write a readme about extra information
    fileID = fopen(fullfile(init.bids_dir,'README'),'a');
    fprintf(fileID,'E-prime behavioural sourcedata aqcuired for the flanker task');
    fclose(fileID);
end


%% Copy scripts for bids dataset creation to the /code directory 
% NO CHANGES NEEDED IN THIS SECTION

%the path of the current script
this_file_path = mfilename('fullpath');
this_file_path = strcat(this_file_path,'.m');

%add paths to sxripts that should be added to /code directory in bids dataset
code_file_paths = {this_file_path};

if strcmp(input.run_mode,'new_BIDS')
    cp_code2bids(init,code_file_paths)
end



%% Print an ending statement
% NO CHANGES NEEDED IN THIS SECTION
fprintf('Added sourcedata to the BIDS dataset in: %s\n\n',init.bids_dir)


end 


