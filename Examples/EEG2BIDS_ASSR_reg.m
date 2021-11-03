function EEG2BIDS_MMN(varargin)

%add paths to relevant toolboxes
addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')
addpath('/home/simonyj/EEG2BIDS/utils/')

%% Setup  

%the name of the bids dataset
bids_dataset_name = 'VIA11_BIDS';


%Specify the data directories
% - If session folder(s) should be created in the bids dataset, data_dir should
%be a struct with the fieldnames corresponding to the session name(s)
% - If no sessions are needed let data_dir be a character array with the
%data_dir path
data_dir.via11 = '/home/simonyj/EEG_ASSR_reg';
data_dir.via15 = '/home/simonyj/EEG_ASSR_reg';
bids_dir = varargin{1}; %bids_dir is parsed as the first input in the function 
%bids_dir = '/home/simonyj/EEG_BIDS_MMN';

%Path to the EEG2BIDS dir from https://github.com/SimonYamazaki/EEG2BIDS
EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';

%The task name
%from BIDS specification: Each task has a unique label that MUST only consist 
%of letters and/or numbers (other characters, including spaces and underscores, are not allowed).
task = 'ASSRreg';

%Search pattern for data files. 
%data_file follows the same structure as data_dir with respect to sessions
%field names must be identical to data_dir field names
data_file.via11 = '*_ASSR_reg*.bdf';
data_file.via15 = '*_ASSR_reg*.bdf';

%keywords in the data_file name that should not be present. 
%if this keyword is found, the file will not be moved to BIDS
nono_keywords_in_filename = {'Flanker','irreg','MMN'};

%search pattern for other files that must exist along the data file
%follows the same structure as data_dir with respect to sessions
%field names must be identical to data_dir field names
%note - if there are sessions without the need of must_exist_files, then
%simply dont define the field of that session
% must_exist_files.via11 = {'*_triggers.mat'}; %currently searches data_dir for these files
% must_exist_files.via15 = {'*_triggers.mat'}; %currently searches data_dir for these files

%files to check for to determine existing subjects in BIDS directory
%follows the same structure as data_dir with respect to sessions
%field names must be identical to data_dir field names
%must include all the sessions defined in data_dir
files_checked.via11 = {'*task-ASSRreg_eeg.bdf','*task-ASSRreg_eeg.json','*task-ASSRreg_events.tsv','*task-ASSRreg_channels.tsv'};
files_checked.via15 = {'*task-ASSRreg_eeg.bdf','*task-ASSRreg_eeg.json','*task-ASSRreg_events.tsv','*task-ASSRreg_channels.tsv'};

% parse a subject info table from database for participant information.
% info goes into participants.tsv
sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
id_col_name = 'famlbnr'; %the column name which represents subject IDs in sub_info_table

%only include these participant info variables
%if no variables are listed all variables are added to the participants.tsv
participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

%path to stimulation files to include in /stimuli directory in bids_dir
stim_files.via11 = {'/home/simonyj/EEG_ASSR_reg/click_40_regular.wav'};
stim_files.via15 = {'/home/simonyj/EEG_ASSR_reg/click_40_regular.wav'};

%Whether to write a scans.tsv file
include_scans_tsv = false; 

%start event value and the number of expected events with this value
trig_start_value = 65281;
n_trig_start = 1;

%Should events.tsv and events.json be loacted in bids_dir or subject folders
%note - if in bids_dir, according to the inheritance principle, the event
%files are general for all subjects and sessions
events_in_sub_dir = true;

%txt file paths to be read
event_txt_file = fullfile(data_dir.via11,'ASSR_events.txt'); % txt file with information about events but not the events itself. This includes trigger values or notes about the events in general. Should have a specific format, check other events.txt
instructions_txt = fullfile(data_dir.via11,'ASSR_reg_instructions.txt'); %txt file with instructions. Should be instructions combined in one single line. 
participants_var_txt = fullfile(data_dir.via11,'participants_variables.txt'); %txt file with a description about the variables in participants.tsv. This could also include levels for categorical variables or units for variables. Has specific format.


%% Configure the setup

%read the subject table for info to go into participants.tsv 
sub_info_table = readtable(sub_info_table_path);
via_id = sub_info_table.(id_col_name); %get subject ids from the subject table. These are needed for functions to load proper subject info later.

%the path of the current script
this_file_path = mfilename('fullpath');
this_file_path = strcat(this_file_path,'.m');

%define sessions, subjects and their data_files (in this case the data_files are bdf files)
%varargin is the arguments that was parsed to this script, e.i. bids_dir and potentially single subject id and session
[sub,ses,bdf_file_names] = define_sub_ses_bdf(data_dir, data_file, via_id, varargin, nono_keywords_in_filename);

%get subjects with the additional files that was specified in the variable "must_exist_files"
if exist('must_exist_files','var')
    [subs_with_all_files,subs_with_additional_files,additional_file_names] = search_must_exist_files(data_dir,via_id,must_exist_files);
    cmp_and_print_subs_with_file(sub,subs_with_additional_files,must_exist_files,ses) % compare the subjects to be moved to the bids_dir with the subjects that has the additional files. This function also prints the comparison.
end

%prellocate memory for information about which sessions should be run
finished_ses = false(1,length(ses));
ses_run = false(1,length(ses));
ses_add = false(1,length(ses));

for s = 1:length(ses)
    %only include subjects that has the additional_files
    if exist('must_exist_files','var')
        excluded_subs = sub.(ses{s})(~ismember(sub.(ses{s}),subs_with_all_files.(ses{s}))); %subjects which does not have one of the must_exist_files
        disp('HERE')
        %print warning if subjects are excluded
        if ~isempty(excluded_subs)
            fprintf('WARNING: Subject %s will not be included in the BIDS directory as they are missing a "must_exist_file" ',excluded_subs{:})
            fprintf('in session %s\n',ses{s})
            bdf_file_names.(ses{s}) = bdf_file_names.(ses{s})(~ismember(sub.(ses{s}),subs_with_all_files.(ses{s}))); %the exlusion of subjects which are already existing in the bids_dir
            sub.(ses{s}) = sub.(ses{s})(ismember(sub.(ses{s}),subs_with_all_files.(ses{s}))); %the exlusion of the subjects who does not have the must_exist_files
        end
    end
    
    %find existing subjects in the bids structure by searching for files_checked
    existing_sub = find_existing_subs(bids_dir,files_checked,ses(s));
    
    if length(varargin)==1 %if only the bids_dir is parsed to this function, e.i. running this script for multiple subjects from data_dir
        bdf_file_names.(ses{s}) = bdf_file_names.(ses{s})(~ismember(sub.(ses{s}),existing_sub.(ses{s}))); %the exlusion of subjects which are already existing in the bids_dir
        sub.(ses{s}) = sub.(ses{s})(~ismember(sub.(ses{s}),existing_sub.(ses{s}))); %the exlusion of subjects which are already existing in the bids_dir
       
        finished_ses(s) = isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s})); %the sessions that are done
        ses_run(s) = ~isempty(sub.(ses{s})) && isempty(existing_sub.(ses{s})); %the sessions that should be run/started/created
        ses_add(s) = ~isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s})); %the existing sessions with subjects to be added to
        
    elseif length(varargin)>1 %running this script for a single subject

        assert(~isempty(sub.(ses{s})),sprintf('A BIDS directory will not be made for subject %s. Check warnings above',varargin{2}))
        
        finished_ses(s) = false; %the sessions that are done
        ses_run(s) = ~isempty(sub.(ses{s})) && isempty(existing_sub.(ses{s})); %the sessions that should be run/started/created
        ses_add(s) = ~isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s})); %the existing sessions with subjects to be added to
    end
end

%only run this script if there are unfinished sessions
assert( ~all(finished_ses), 'All relevant subject files are moved to BIDS data structure in all sessions. Add more subject files to the data_dir or run EEG2BIDS.sh for a specific subject.')

if any(ses_run)
    if length(ses(ses_run))==1
        if strcmp(ses{ses_run},'None')
            fprintf('Creating new BIDS dataset from subject files \n')
        end
    else
        fprintf('Creating new BIDS dataset session %s from subject files \n',ses{ses_run})
    end
    run_mode = 'new_BIDS';
else
    run_mode = 'exist_BIDS';
end

if any(ses_add) %sessions to add assuming that other parts of the BIDS dataset have been created successfully
    ses_to_add = ses(ses_add);
    for s = 1:length(ses_to_add)
        for ss = 1:length(sub.(ses_to_add{s}))
            fprintf('Moving subject %s files into BIDS dataset for session %s \n',sub.(ses_to_add{s}){ss},ses_to_add{s})
        end
    end
end


%% Copy the stimulation files to /stim direcotry

if exist('stim_files','var')
    
    stim_dir = fullfile(bids_dir,'/stimuli'); %the stimuli dir in the bids_dir
    if not(isfolder(stim_dir)) %only make the stimuli dir if it does not exist
        mkdir(stim_dir)
    end
    
    %get path to stim files in bids_dir and the name + extension of files
    [bids_stim_file_path, bids_stim_file_name] = get_bids_stim_files(stim_files,stim_dir);

    %copy them into the appropriate folder
    if strcmp(run_mode,'new_BIDS')
        cp_ses_files(stim_files, bids_stim_file_path)    
    end

end



%% Generate BIDS structure and files

%%%%%% Use data2bids function on each subject in loop %%%%%%%%

% for more information on data2bids function see: 
% https://github.com/SimonYamazaki/fieldtrip/blob/master/data2bids.m
% which is a modified version of: https://github.com/fieldtrip/fieldtrip/blob/master/data2bids.m

if not(isfolder(bids_dir))
    mkdir(bids_dir)
end

%read instructions into cell 
if exist('instructions_txt','var')
    InstructionsC = read_txt(instructions_txt);
end

write_events = true;
write_channels = true;

%loop over sessions and subjects to make bids_dir for

for sesindx=1:numel(ses)
    for subindx=1:numel(sub.(ses{sesindx}))
    
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy'; %only copy the files
    cfg.datatype  = 'eeg'; %the type of data

    % specify the output directory (bids_dir)
    cfg.bidsroot  = bids_dir;
    
    %By default if no session is specified the cell array "ses" is named
    %'None' through functions in the EEG2BIDS_tool_dir
    if ~strcmp(ses{sesindx},'None')
        cfg.ses       = ses{sesindx};
    end
    
    % get subject ID 
    cfg.sub       = sub.(ses{sesindx}){subindx};
    sub_int       = str2num(cfg.sub);
    
    %specify that no scans.tsv file is needed for this dataset
    cfg.include_scans = include_scans_tsv;
    
    % define data file for current subject
    if isstruct(data_dir)
        cfg.dataset   = char(fullfile(data_dir.(ses{sesindx}),bdf_file_names.(ses{sesindx}){subindx}));
    else
        cfg.dataset   = char(fullfile(data_dir,bdf_file_names.(ses{sesindx}){subindx}));
    end
    
    %general information to be put into dataset_description.json file
    if strcmp(run_mode,'new_BIDS')
        cfg.dataset_description.BIDSVersion = '1.6';
        cfg.dataset_description.Name = bids_dataset_name;
        cfg.dataset_description.DatasetType = 'raw';
        cfg.dataset_description.EthicsApprovals = {'The local Ethical Committee (Protocol number: H 16043682)','The Danish Data Protection Agency (IDnumber RHP-2017-003, I-suite no. 05333)'};
    end
    
    % specify the information for the participants.tsv file
    cfg.participants = make_participants_cfg(sub_info_table,via_id,sub_int,participant_info_include);
    
    % specify some general information that will be added to the eeg.json file
    cfg.InstitutionName             = 'Centre for Functional and Diagnostic Imagning and Research, Danish Research Center for Magnetic Resonance, Amager and Hvidovre hospital';
    cfg.InstitutionAddress          = 'Kettegard Allé 30, DK-2650 Hvidovre, Denmark';
    
    % provide the mnemonic and long description of the task
    cfg.TaskName        = task;
    cfg.TaskDescription = '????';

    % EEG specific configs saved in *_eeg.json file 
    cfg.eeg.PowerLineFrequency    = 50;
    cfg.eeg.Manufacturer          = 'Biosemi';
    cfg.eeg.ManufacturersModelName = '????';
    cfg.eeg.SoftwareVersions      = '????';
    %cfg.eeg.CogPOID               = '????';
    cfg.eeg.DeviceSerialNumber    = '????';
    cfg.eeg.EEGReference          = 'Common Mode Sense (CMS) and Driven Right Leg (DRL)'; 
    
    %include the instructions if they are read
    if exist('InstructionsC','var')
        cfg.eeg.Instructions          = InstructionsC{1};
    end
    
    %software filters
    swf.filter_characteristic = '????';
    swf.filter_parameter = 10;
    swf3.filter_characteristic = '????';
    swf3.filter_parameter = 100;
    cfg.eeg.SoftwareFilters.Filter1       = swf;
    cfg.eeg.SoftwareFilters.Filter3       = swf3;
    
    %manufacturer information
    cfg.eeg.CapManufacturer = 'Biosemi';
    cfg.eeg.CapManufacturersModelName = '????';
    cfg.eeg.EEGPlacementScheme = 'radial';

    %%%%%%%  HEADER  %%%%%%%%%
    %read the header of bdf_file
    cfg.hdr = ft_read_header(cfg.dataset);
    
    %specify external channel info to the header
    %note; this does not change the header of the data file
    EXG_chan_types = cell(8,1);
    EXG_chan_types(:) = {'EMG'};
    cfg.hdr.chantype(end-8:end-1) = EXG_chan_types;
    cfg.hdr.chantype(end) = {'TRIG'};

    EXG_chan_units = cell(8,1);
    EXG_chan_units(:) = {'uV'};
    cfg.hdr.chanunit(end-8:end-1) = EXG_chan_units;
    cfg.hdr.chanunit(end) = {'n/a'};

    %%%%%%%%  EVENTS %%%%%%%%
    event_struct = ft_read_event(cfg.dataset);
    
    %check that the .bdf file only contains the expected amount of events
    if exist('trig_start_value','var')
        if sum([event_struct.value]==trig_start_value)~=n_trig_start
            fprintf('Subject %s has more trigger start events than expected. Check whether the .bdf file includes tasks other than %s.',cfg.sub,task)
            %fprintf('WARNING: Not including subject %s in the bids structure as the .bdf file includes more events than expected',cfg.sub,task)
        end
    end
    
    fs = cfg.hdr.Fs;  %e.g. 4096
    delay = 38;
    
    bdf_event_samples = [event_struct.sample];   
    conditionlabels = cell(1,120);
    conditionlabels{1} = 'click';
    trl2(1,1)=round(bdf_event_samples(1)+(38/1000)*fs);
    trl2(1,2)=round(bdf_event_samples(1)+1000+(38/1000)*fs); %the first two terms in this definition is arbitrary
    
    for k = 2:120
        trl2(k,1)=round(trl2(k-1,1)+3*fs);
        trl2(k,2)=round(trl2(k-1,2)+3*fs);
        conditionlabels{k}='click';
    end
    
    bdf_event_table = struct2table(event_struct); 
    type = repmat({'STATUS'},length(conditionlabels),1) ;
    value = cell(length(conditionlabels),1);
    offset = cell(length(conditionlabels),1); %keep this variable
    duration = num2cell(ones(length(conditionlabels),1));
    sample = trl2(:,1);
    
    generated_event_table = table(type,sample,value,offset,duration);
    event_table = [bdf_event_table;generated_event_table];
    
    event_table.stim_file = [cell(length(event_struct),1); repmat(bids_stim_file_name.(ses{sesindx})(1),length(conditionlabels),1)];
    event_table.delay = ones(length(event_struct)+length(conditionlabels),1)*delay/1000;
    event_table.conditionlabel = [cell(length(event_struct),1); conditionlabels(:)];

    cfg.events = table2struct(event_table);
    cfg.keep_events_order = true; %should the events be sorted according to sample or should it keep the order in cfg.events?
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAKING THE SUBJECT BIDS DATASET
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FOR THE SUBJECT IN LOOP
    
    
    %make bids dataset with the cfg struct
    data2bids(cfg);
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
    %%%%% Write events.json %%%%%% 
    if events_in_sub_dir 
        %the name of the events.json 
        %place the events.json in subject directory if events_in_sub_dir is true
        if isstruct(data_dir)
            event_json = fullfile(bids_dir, sprintf('/sub-%1$s/ses-%2$s/%3$s/sub-%1$s_ses-%2$s_task-%4$s_events.json',cfg.sub,ses{sesindx},cfg.datatype,task));
        else
            event_json = fullfile(bids_dir, sprintf('/sub-%1$s/%2$s/sub-%1$s_task-%3$s_events.json',cfg.sub,cfg.datatype,task));
        end
    else
        %place the events.json in bids_dir if events_in_sub_dir is false.
        event_json = fullfile(bids_dir, sprintf('task-%s_events.json',task));
    end
    
    if write_events
        %description, units, or categorical levels of variables (columns) in events.tsv
        %this information goes into events.json
        cfg.TaskEventsDescription.onset.Description = 'Onset of stimuli. The onset of the sound being played for the subject and not the onset of epoch';
        cfg.TaskEventsDescription.onset.Units = 's';

        cfg.TaskEventsDescription.duration.Description = 'Duration of stimuli';
        cfg.TaskEventsDescription.duration.Units = 's';

        cfg.TaskEventsDescription.sample.Description = '????';
        cfg.TaskEventsDescription.sample.Units = 's';

        cfg.TaskEventsDescription.type.Description = '????';
        cfg.TaskEventsDescription.type.Levels.STATUS = 'STATUS type';
        cfg.TaskEventsDescription.type.Levels.Epoch = 'Epoch type';
        cfg.TaskEventsDescription.type.Levels.CM_in_range = 'CM_in_range type';

        cfg.TaskEventsDescription.delay.Description = 'Delay between the trigger and when the sound is actually played in the headphones of 37 ms';
        cfg.TaskEventsDescription.delay.Units = 's';

        cfg.TaskEventsDescription.conditionlabel.Description = '????';
        cfg.TaskEventsDescription.conditionlabel.Levels.Int_1 = '????';
        cfg.TaskEventsDescription.conditionlabel.Levels.Int_2 = '????';

        cfg.TaskEventsDescription.StimulusPresentation.OperatingSystem = '????';
        cfg.TaskEventsDescription.StimulusPresentation.SoftwareName = '????';
        %cfg.TaskEventsDescription.StimulusPresentation.SoftwareRRID = '????';
        cfg.TaskEventsDescription.StimulusPresentation.SoftwareVersion = '????';
        %cfg.TaskEventsDescription.StimulusPresentation.code = '????';

        if exist('event_txt_file','var')
            %read txt to a cell 
            eventsC = read_txt(event_txt_file);

            %write info from the event_txt_file with a specific formating and
            %extra notes to the config struct that generates events.json 
            %add value and notes to the event.json  
            extra_notes = ' ';
            cfg.TaskEventsDescription = read_events_txt(cfg.TaskEventsDescription,eventsC,extra_notes);
        end

        %write the file 
        fn = fieldnames(cfg.TaskEventsDescription);
        TaskEventsDescription_settings = keepfields(cfg.TaskEventsDescription, fn);
        ft_write_json(event_json, TaskEventsDescription_settings);
    end
    
    %make sure not to write events.json file more than once if it is to be
    %placed in bids_dir, e.i if sub-XXX is in file name the events.json 
    %should not be written next iteration of subject loop as only one
    %should be made jf. the inheritance principle
    if ~contains(event_json, sprintf('sub-%s',cfg.sub))
        write_events = false;
    end
    
    
    end
end


%% Write channels.json file 

%as all tasks are done with the same EEG cap and channels, only one
%channels.josn file is written in the bids_dir. 

if strcmp(run_mode,'new_BIDS')
    filename = fullfile(bids_dir, sprintf('task-%s_channels.json',task));
    cfg.ChannelsDescription.name.Description = 'name of channel label????';
    cfg.ChannelsDescription.name.Levels.EXG1 = 'External channel 1. Mastoid left ear';
    cfg.ChannelsDescription.name.Levels.EXG2 = 'External channel 2. Mastoid right ear';
    cfg.ChannelsDescription.name.Levels.EXG3 = 'External channel 3, Left ear lobe';
    cfg.ChannelsDescription.name.Levels.EXG4 = 'External channel 4. Right ear lobe';
    cfg.ChannelsDescription.name.Levels.EXG5 = 'External channel 5. Nose';
    cfg.ChannelsDescription.name.Levels.EXG6 = 'External channel 6. Below participants right eye';
    cfg.ChannelsDescription.name.Levels.EXG7 = 'External channel 7. Above participants right eye';
    cfg.ChannelsDescription.name.Levels.EXG8 = 'External channel 8. Pulse left hand';

    fn = fieldnames(cfg.ChannelsDescription);
    ChannelsDescription_settings = keepfields(cfg.ChannelsDescription, fn);
    ft_write_json(filename, ChannelsDescription_settings);
end



%% Write participants.json from .txt file

if strcmp(run_mode,'new_BIDS')
    
    %any additional info to include in json
    cfg.ParticipantsDescription.participant_id.Description = 'The identification number of the subject';

    %read from txt 
    participants_var = read_txt(participants_var_txt);
    
    %read the participants_var as a cell into the config struct
    cfg.ParticipantsDescription = read_participants_var_txt(cfg.ParticipantsDescription,participants_var,participant_info_include);
    
    %check which variables in the participants.tsv that are not described in the
    %config struct to generate theparticipants.json
    non_described_vars = check_described_variables_in_tsv(bids_dir,cfg.ParticipantsDescription,sub,'participants.tsv');
    
    %write the file 
    filename = fullfile(bids_dir, 'participants.json');
    fn = fieldnames(cfg.ParticipantsDescription);
    ParticipantsDescription_settings = keepfields(cfg.ParticipantsDescription, fn);
    ft_write_json(filename, ParticipantsDescription_settings);
end


%% Copy this script to the /code directory in BIDS structure 

code_dir = fullfile(bids_dir,'/code');

if not(isfolder(code_dir))
    mkdir(code_dir)
end

%copy this current script into /code in bids_dir
[folder,name,ext]=fileparts(this_file_path);
copyfile(this_file_path, fullfile(code_dir,strcat(name,ext)), 'f')

%also copy BIDS validator, json fix scripts and job scripts
if strcmp(run_mode,'new_BIDS')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/change_json_int_keys.py'), fullfile(code_dir,'/change_json_int_keys.py'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG2BIDS_job.sh'), fullfile(code_dir,'/EEG2BIDS_job.sh'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG2BIDS.sh'), fullfile(code_dir,'/EEG2BIDS.sh'), 'f')
end


%% Write a readme and .bidsignore file 

if strcmp(run_mode,'new_BIDS')
    %write a readme about extra information
    fileID = fopen(fullfile(bids_dir,'README'),'w');
    fprintf(fileID,'The EEG dataset includes 4 tasks performed in the following order: ASSR regular (first task), ASSR irregular (second task), Flanker (third task) and MMN (forth task)\n');
    fclose(fileID);
    
    %write .bidsignore file for the BIDS validator
    %.bidsignore file has same syntax as .gitignore
    fileID = fopen(fullfile(bids_dir,'.bidsignore'),'w');
    fprintf(fileID,'/cluster_submissions/'); %add lines to the .bidsignore file
    fclose(fileID);
end


%% Print an ending statement

if strcmp(run_mode,'new_BIDS')
    fprintf('Created BIDS dataset in: %s\n\n',bids_dir)
else
    fprintf('Added subjects to the BIDS dataset in: %s\n\n',bids_dir)
end


end 

