function EEG2BIDS_MMN2(varargin)

%add paths to relevant toolboxes
addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/home/simonyj/EEG2BIDS/utils/')
%addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')


%% Setup  
% CHANGES NEEDED IN THIS SECTION

%General comments
% - Comment/remove lines in this section that are not needed if OPTIONAL
% - Search patterns are given as inputs to MATLAB function "dir", i.e use asterisk
% - Go through each section in this script with "CHANGES NEEDED IN THIS SECTION" 
%and make changes appropriate for your dataset

%Path to the EEG2BIDS dir from https://github.com/SimonYamazaki/EEG2BIDS
init.EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';

%The name of the bids dataset
% - name of your BIDS dataset to go into the dataset_description.json
% - this is different that bids_dir, which is a path to your BIDS folder
init.bids_dataset_name = 'VIA11_BIDS';

%The task name
% - The task that this script concerns
% - Each task has a unique label that MUST only consist of letters and/or 
%numbers. Other characters, including spaces and underscores, are not allowed
init.task = 'MMN';


%Specify data directories
% - If session folders should be created in the bids dataset, data_dir should
%be a struct with the fieldnames corresponding to the session names
% - If no sessions are needed let data_dir be a character array with the
%data_dir path
% - If data is not located in the same folder refer to "Manually specifying
%data files" below and comment/remove definitions of init.data_dir,
%init.data_file, init.nono_keywords_in_filename, init.id_search_method
init.data_dir.via11 = '/home/simonyj/EEG_MMN';
init.data_dir.via15 = '/home/simonyj/EEG_MMN';
init.bids_dir = varargin{1}; %bids_dir is parsed as the first input in the function 

%Search pattern for data files in data_dir
% - data_file follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - searches data_dir for data_file
init.data_file.via11 = '*_MMN.bdf';
init.data_file.via15 = '*_MMN.bdf';

%Keywords in the data_file name that should not be present
% - OPTIONAL
% - if this keyword is found, the file will not be moved to BIDS dataset
init.nono_keywords_in_filename = {'Flanker','ASSR'};

%Specify method to extract subject id from file name
% - assumes that the subject ids to include in the bids dataset can be 
%extracted from data_file
% - if the subject id can not be extracted from the file name, refer to 
%"Manually specifying data files" below
% - must be a cell array with 'manual' or 'auto'
% - the 'auto' method will use an automatic id detection 
% - if the 'manual' method is specified, the second element in the cell array
%should be a double array with character indexes for the subject id in the 
%file name string, that is the whole file name and not data_file. Assumes
%that subject ids is extracted from the same character indexes in all files
%example: init.id_search_method = {'manual',1:3};
%init.id_search_method = {'auto'};


%Manually specifying data files
% - OPTIONAL
% - if subject ids cant be extracted from data_file, add them manually
% - Do not define these structs if data_dir and data_file is defined
%init.sub.via11 = {'009'  '146'  '302'};
%init.sub_files.via11 = {'/path/to/file1.bdf','/path/to/file2.bdf','/path/to/file3.bdf'};
%init.sub.via15 = {'009'  '146'  '302'};
%init.sub_files.via15 = {'/path/to/file1.bdf','/path/to/file2.bdf','/path/to/file3.bdf'};

%A subject ID prefix for subject folders in bids_dir
% - OPTIONAL
init.ID_prefix = 'via';

%Search pattern for other files that must exist along the data_file
% - OPTIONAL
% - follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - currently searches data_dir for these files
% - EXEPTION: if there are sessions without the need of must_exist_files, then
%simply dont define the field of that session in must_exist_files
init.must_exist_files.via11 = {'*_triggers.mat'}; 
init.must_exist_files.via15 = {'*_triggers.mat'}; 


%Search pattern for files that must exist to determine existing subjects in BIDS directory
% - follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - must include all the sessions defined in data_dir
% - files_checked searches for these files in the /eeg folder within each
% subject folder
init.files_checked.via11 = {sprintf('*task-%s_eeg.bdf',init.task),sprintf('*task-%s_eeg.json',init.task),...
                       sprintf('*task-%s_events.tsv',init.task),sprintf('*task-%s_channels.tsv',init.task)};
init.files_checked.via15 = init.files_checked.via11;


%Parse a subject info table from database for participant information.
% - info goes into participants.tsv
% - assumes the table has a column of subject id, where rows consists of 
%participant info for a particular subject id 
% - assumes that participant info is identical for all tasks in bids_dir
init.sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
init.sub_info_table = readtable(init.sub_info_table_path); %read the table 

%Get subject ids coloum from the sub_info_table table. Each element in this 
%coloumn must be a unique identifier for that particular subject.
init.IDs_col = init.sub_info_table.('famlbnr'); %keep this intermediate step

%Transform the IDs from sub_info_table to the character arrays that is expected 
%from the subject ID extraction of file names. If data files were manually 
%specified, then transform the subject IDs from the sub_info_table to the 
%format of the subject IDs specified in init.sub
% - example: if the ID coloum in sub_info_table is integers, but you expect
%character arrays of leading zeros transformation should be as below:
init.IDs = cellstr(num2str(init.IDs_col,'%03d')); 

% - only include these participant info variables (columns) in participants.tsv
% - if no variables are listed, all variables are added to the participants.tsv
init.participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

%Path to stimulation files to include in /stimuli directory in bids_dir
% - OPTIONAL
init.stim_files.via11 = {'/home/simonyj/EEG_MMN/std.wav','/home/simonyj/EEG_MMN/dev1.wav',...
            '/home/simonyj/EEG_MMN/dev2.wav','/home/simonyj/EEG_MMN/dev3.wav'};
init.stim_files.via15 = {'/home/simonyj/EEG_MMN/std.wav','/home/simonyj/EEG_MMN/dev1.wav',...
            '/home/simonyj/EEG_MMN/dev2.wav','/home/simonyj/EEG_MMN/dev3.wav'};

%Whether to include a scans.tsv file
init.include_scans_tsv = true;

%Whether to write dataset_description.json
% - dataset_description.json should always be written unless multiple tasks 
%are combined into one bids_dir
init.write_dataset_description = true; 

%Whether to include events.tsv
% - events MAY be either stimuli presented to the participant or participant responses
% - events.tsv file are generated based on the events field in the bdf 
%file header by default. 
% - refer to the events part of section "Generate BIDS structure and files"
%in this script for any custom changes to this events.tsv file outside the 
%events in the bdf file header
init.include_events_tsv = true; 

%Simple verification of the expected amount of triggers in bdf file header
% - start event value in eeg files header
init.trig_start_value = 65281;
% - number of expected events with this start event value
init.n_trig_start = 1;

%Should events.json be loacted in bids_dir or subject folders
% - if in bids_dir, according to the inheritance principle, the event
%files are general for all subjects and sessions
init.events_in_sub_dir = true; %false -> events.json will be located in bids_dir

%txt file paths to be read
% - OPTIONAL
init.event_txt_file = fullfile(init.data_dir.via11,'MMN_events.txt'); % txt file with information about events but not the events itself. This includes trigger values or notes about the events in general. Should have a specific format, check other events.txt in github repo
init.instructions_txt = fullfile(init.data_dir.via11,'MMN_instructions.txt'); %txt file with instructions. Should be instructions combined in one single line of a txt file. 
init.participants_var_txt = fullfile(init.data_dir.via11,'participants_variables.txt'); %txt file with a description about the variables in participants.tsv. This could also include levels for categorical variables or units for variables. Has specific format.

%extra notes to go into events.json 
% - OPTIONAL
init.extra_notes = ' The variables from subject_*SUB_ID*_MMN_triggers.mat files are added to the events.tsv files as start_sample -> start_sample, rand_ISI -> rand_ISI, mmn-codes -> conditionlabels.';


init.varargin = varargin;

input = configure_init(init);


%% Generate BIDS structure and files
% CHANGES NEEDED IN THIS SECTION

%%%%%% Use data2bids function on each subject in loop %%%%%%%%

% for more information on data2bids function see: 
% https://github.com/SimonYamazaki/fieldtrip/blob/master/data2bids.m
% which is a modified version of: https://github.com/fieldtrip/fieldtrip/blob/master/data2bids.m


%loop over sessions and subjects to make bids_dir for
for sesindx=1:numel(input.ses)
    for subindx=1:numel(input.sub.(input.ses{sesindx}))
    
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy'; %only copy the files
    cfg.datatype  = 'eeg'; %the type of data
    cfg.sesindx = sesindx;
    cfg.subindx = subindx;
    
    %Configure inputs and add it to the cfg struct. The cfg struct is unique
    %for every iteration in this loop, i.e. for every session and subject
    cfg = configure_input(cfg,input);
    
    %general information to be put into dataset_description.json file
    if init.write_dataset_description
        cfg.dataset_description.BIDSVersion = '1.6';
        cfg.dataset_description.Name = init.bids_dataset_name;
        cfg.dataset_description.DatasetType = 'raw';
        cfg.dataset_description.EthicsApprovals = {'The local Ethical Committee (Protocol number: H 16043682)','The Danish Data Protection Agency (IDnumber RHP-2017-003, I-suite no. 05333)'};
    end
    
    %Specify the information for the participants.tsv file
    cfg.participants = make_participants_cfg(cfg,input);
    
    %Specify some general information that will be added to the eeg.json file
    cfg.InstitutionName             = 'Centre for Functional and Diagnostic Imagning and Research, Danish Research Center for Magnetic Resonance, Amager and Hvidovre hospital';
    cfg.InstitutionAddress          = 'Kettegard Allé 30, DK-2650 Hvidovre, Denmark';
    
    %Provide the mnemonic and long description of the task
    cfg.TaskName        = init.task;
    cfg.TaskDescription = '????';

    % EEG specific configs saved in *_eeg.json file 
    cfg.eeg.PowerLineFrequency    = 50;
    cfg.eeg.Manufacturer          = 'Biosemi';
    cfg.eeg.ManufacturersModelName = '????';
    cfg.eeg.SoftwareVersions      = '????';
    %cfg.eeg.CogPOID               = '????';
    cfg.eeg.DeviceSerialNumber    = '????';
    cfg.eeg.EEGReference          = 'Common Mode Sense (CMS) and Driven Right Leg (DRL)'; 
    
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
    %this part can be removed if no additional channel info is needed
    %first the header of the eeg file is read and then additional 
    %channel information is added. Modififying the cfg.hdr will not 
    %change anything in the eeg file, only in the custom header struct to 
    %be parsed to the function that generates the bids files
    
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
    %This part can be removed if no additional events should be added to
    %the events.tsv. If this part is removed, the only things that go into
    %the events.tsv file is the events read in the eeg file header.
    %first the header of the eeg file is read and then additional 
    %events can be added. Modififying the event_struct will not 
    %change anything in the eeg file, only in the event_struct that is 
    %parsed to the function that generates the bids files
    
    if init.include_events_tsv %only include the events.tsv file if specified in the init struct

        %read the events of the bdf file
        event_struct = ft_read_event(cfg.dataset);

        %check that the .bdf file only contains the expected amount of events
        if isfield(init,'trig_start_value')
            if sum([event_struct.value]==init.trig_start_value)~=init.n_trig_start
                fprintf('WARNING: Subject %s has more trigger start events than expected. Check whether the data file includes tasks other than %s\n.',cfg.sub,init.task)
            end
        end

        %extract the sampling frequency from somewhere
        fs = cfg.hdr.Fs; 

        %%%%% Define events to go into events.tsv %%%%%%
        delay = 37;
        load(sprintf('%s/subject_%s_MMN_triggers.mat',init.data_dir.(input.ses{sesindx}),cfg.file_sub_id));

        % estimate the start of the first sound
        bdf_event_samples = [event_struct.sample];    
        start_idx = [event_struct.value]==65281;
        empty_idx = cellfun(@isempty,{event_struct.value},'UniformOutput',1);
        timestart_idx = false(1,length(empty_idx));
        timestart_idx(not(empty_idx))=start_idx;

        timestart = bdf_event_samples(timestart_idx)/fs;

        %create the rest of the 1800 trials and correct for the latency between the
        %trigger and the sound
        S.trl(1,1)=timestart*fs+round((delay/1000)*fs); %-0.1*fs; %(the -0.1*fs shifts the start of the epoch to be 100ms before the sound which SPM wants)
        S.conditionlabels{1,1} = 'std';
        duration_vec(1,1) = 50/1000;
        table_sf{1,1} = input.bids_stim_file_name.(input.ses{sesindx}){1};

        trig=round(start_samples/(44100/4096));

        for i = 2:length(trig)
            S.trl(i,1)=S.trl(1,1)+trig(i);
            if mmn_codes(i)==1
                S.conditionlabels{i,:}= 'std';
                duration_vec(i,1) = 50/1000;
                table_sf{i} = input.bids_stim_file_name.(input.ses{sesindx}){1};
            elseif mmn_codes(i) ==2
                S.conditionlabels{i,:}= 'dev1';
                duration_vec(i,1) = 50/1000;
                table_sf{i} = input.bids_stim_file_name.(input.ses{sesindx}){2};
            elseif mmn_codes(i) ==3
                S.conditionlabels{i,:}='dev2';
                duration_vec(i,1) = 100/1000;
                table_sf{i} = input.bids_stim_file_name.(input.ses{sesindx}){3};
            elseif mmn_codes(i) ==4
                S.conditionlabels{i,:}='dev3';
                duration_vec(i,1) = 100/1000;
                table_sf{i} = input.bids_stim_file_name.(input.ses{sesindx}){4};
            end
        end

        bdf_event_table = struct2table(event_struct); 
        type = repmat({'STATUS'},length(S.conditionlabels),1) ;
        value = cell(length(S.conditionlabels),1);
        offset = cell(length(S.conditionlabels),1); %keep this variable
        duration = num2cell(duration_vec);
        sample = S.trl(:,1);

        generated_event_table = table(type,sample,value,offset,duration);
        event_table = [bdf_event_table;generated_event_table];

        event_table.stim_file = [cell(length(event_struct),1); table_sf'];
        event_table.delay = ones(length(event_struct)+length(S.conditionlabels),1)*delay/1000;
        event_table.conditionlabel = [cell(length(event_struct),1); S.conditionlabels(:)];
        event_table.rand_ISI = [cell(length(event_struct),1); num2cell(rand_ISI')];
        event_table.start_samples = [cell(length(event_struct),1); num2cell(start_samples')];

        cfg.events = table2struct(event_table);
        cfg.keep_events_order = true; %should the events be sorted according to sample or should it keep the order in cfg.events?
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%% MAKING THE SUBJECT BIDS DATASET FOR THE SUBJECT IN LOOP %%%%%%% 
    
    %make bids dataset with the cfg struct
    data2bids(cfg);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if input.init.write_events
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

        cfg.TaskEventsDescription.rand_ISI.Description = '????';
        cfg.TaskEventsDescription.rand_ISI.Units = '????';

        cfg.TaskEventsDescription.start_samples.Description = '????';
        cfg.TaskEventsDescription.start_samples.Units = '????';

        cfg.TaskEventsDescription.StimulusPresentation.OperatingSystem = '????';
        cfg.TaskEventsDescription.StimulusPresentation.SoftwareName = '????';
        %cfg.TaskEventsDescription.StimulusPresentation.SoftwareRRID = '????';
        cfg.TaskEventsDescription.StimulusPresentation.SoftwareVersion = '????';
        %cfg.TaskEventsDescription.StimulusPresentation.code = '????';

        %write the file 
        fn = fieldnames(cfg.TaskEventsDescription);
        TaskEventsDescription_settings = keepfields(cfg.TaskEventsDescription, fn);
        ft_write_json(event_json, TaskEventsDescription_settings);
        fprintf('writing %s\n',event_json)
    end
    
    %make sure not to write events.json file more than once if it is to be
    %placed in bids_dir, e.i if sub-XXX is in file name the events.json 
    %should not be written next iteration of subject loop as only one
    %should be made jf. the inheritance principle
    if ~contains(cfg.event_json_file, sprintf('sub-%s',cfg.sub))
        input.init.write_events = false;
    end
    
    
    end
end


%% Write channels.json file 
% CHANGES NEEDED IN THIS SECTION

%All tasks are assumed to be performed with the same EEG cap and channels,
%therefore only one channels.josn file is written in the bids_dir. 
%As of now, the channels.json file only includes non-standard channels

if strcmp(input.run_mode,'new_BIDS')
    channel_json = fullfile(init.bids_dir, sprintf('task-%s_channels.json',init.task));
    ChannelsDescription.name.Description = 'name of channel label????';
    ChannelsDescription.name.Levels.EXG1 = 'External channel 1. Mastoid left ear';
    ChannelsDescription.name.Levels.EXG2 = 'External channel 2. Mastoid right ear';
    ChannelsDescription.name.Levels.EXG3 = 'External channel 3, Left ear lobe';
    ChannelsDescription.name.Levels.EXG4 = 'External channel 4. Right ear lobe';
    ChannelsDescription.name.Levels.EXG5 = 'External channel 5. Nose';
    ChannelsDescription.name.Levels.EXG6 = 'External channel 6. Below participants right eye';
    ChannelsDescription.name.Levels.EXG7 = 'External channel 7. Above participants right eye';
    ChannelsDescription.name.Levels.EXG8 = 'External channel 8. Pulse left hand';

    fn = fieldnames(ChannelsDescription);
    ChannelsDescription_settings = keepfields(ChannelsDescription, fn);
    ft_write_json(channel_json, ChannelsDescription_settings);
    fprintf('writing %s\n',channel_json)
end



%% participants.json from .txt file
%NO CHANGES NEEDED IN THIS SECTION

%All participant info is assumed to be identical for all tasks and sessions
if strcmp(input.run_mode,'new_BIDS')
    write_participants_json(init)
end

%% Copy scripts for bids dataset creation to the /code directory 
% NO CHANGES NEEDED IN THIS SECTION

%the path of the current script
this_file_path = mfilename('fullpath');
this_file_path = strcat(this_file_path,'.m');

%add paths to sxripts that should be added to /code directory in bids dataset
code_file_paths = {this_file_path};
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/change_json_int_keys.py');
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/EEG2BIDS_job.sh');
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/EEG2BIDS.sh');

if strcmp(input.run_mode,'new_BIDS')
    cp_code2bids(init,code_file_paths)
end


%% Write a readme and .bidsignore file 
% CHANGES NEEDED IN THIS SECTION

if strcmp(input.run_mode,'new_BIDS')
    %write a readme about extra information
    fileID = fopen(fullfile(init.bids_dir,'README'),'a');
    fprintf(fileID,'The EEG dataset includes 4 tasks performed in the following order: ASSR regular (first task), ASSR irregular (second task), Flanker (third task) and MMN (forth task)\n');
    fclose(fileID);
    
    %write .bidsignore file for the BIDS validator
    %.bidsignore file has same syntax as .gitignore
    fileID = fopen(fullfile(init.bids_dir,'.bidsignore'),'a');
    fprintf(fileID,'/cluster_submissions/'); %add lines to the .bidsignore file
    fclose(fileID);
end


%% Print an ending statement
% NO CHANGES NEEDED IN THIS SECTION

if strcmp(input.run_mode,'new_BIDS')
    fprintf('Created BIDS dataset in: %s\n\n',init.bids_dir)
else
    fprintf('Added subjects to the BIDS dataset in: %s\n\n',init.bids_dir)
end


end 


