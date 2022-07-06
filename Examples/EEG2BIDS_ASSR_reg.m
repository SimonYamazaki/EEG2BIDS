function EEG2BIDS_ASSR_reg(varargin)
%The first input to function is the bids_dir, that is the name of the 
%new directory that will be made
%If this dataset should be included in an already existing
%bids_dir then simply use this function with the same bids_dir

% This function takes up to 3 inputs: '{bids_dir}','{subject id}','{session}'
%only the first argument is mandatory

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
% - if in doubt about a spefific files and fields in json files refer to
% the specification at https://bids.neuroimaging.io/specification.html

%Path to the cloned EEG2BIDS dir from https://github.com/SimonYamazaki/EEG2BIDS
init.EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';

%The name of the bids dataset
% - name of your BIDS dataset to go into the dataset_description.json
% - this is different that bids_dir, which is a path to your BIDS folder
% - for multiple tasks in one bids_dir this name should be identical
init.bids_dataset_name = 'VIA11_BIDS';

%The task name
% - The task that this script concerns
% - Each task has a unique label that MUST only consist of letters and/or 
%numbers. Other characters, including spaces and underscores, are not allowed
init.task = 'ASSRreg';


%Specify data directories
% - If session folders should be created in the bids dataset, data_dir should
%be a struct with the fieldnames corresponding to the session names
% - If no sessions are needed let data_dir be a character array with the
%path to the data_dir
% - If data is not located in the same folder or the subject ids cannot be 
%extracted from file names refer to "Manually specifying data files" below 
%and comment/remove definitions of init.data_dir, init.data_file, 
%init.nono_keywords_in_filename, init.id_search_method and init.id_trans
init.data_dir.via11 = '/mrhome/simonyj/nobackup/###_ASSR_reg';
%init.data_dir.via15 = '/home/simonyj/EEG_MMN';
init.bids_dir = varargin{1}; %dont change this! bids_dir is parsed as the first input in the function 

%Search pattern for data files in data_dir
% - data_file follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - searches data_dir for data_file
init.data_file.via11 = '*_ASSR_reg.bdf';
%init.data_file.via15 = '*_MMN.bdf';

%Keywords in the data_file name that should not be present
% - OPTIONAL
% - if this keyword is found, the file will not be moved to BIDS dataset
% - this functionality looks for any substring, thus careful you dont
% substring something that you want, i.e. if you want ASSR_irreg.bdf files,
%and dont want ASSR_reg.bdf, dont just write 'reg' below, instead do '_reg'
init.nono_keywords_in_filename = {'Flanker','MMN','irreg'};


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
%init.must_exist_files.via11 = {'/mrhome/simonyj/nobackup/###_MMN/*_triggers.mat'};  %'/home/simonyj/EEG_MMN/**/*_triggers.mat'
%init.must_exist_files.via15 = {'/mrhome/simonyj/nobackup/###_MMN/*_triggers.mat'}; 
%init.id_from_folder = false; %false -> extracts id from filename, true -> find it from folder name
%init.must_exist_files_id_search = {'manual',9:11}; %from either directory or file name


%Search pattern for files that must exist to determine existing subjects in BIDS directory
% - these files may vary depending on the task and eeg file format,
% however, must be specified!
% - follows the same structure as data_dir with respect to sessions
% - field names must be identical to data_dir field names
% - must include all the sessions defined in data_dir
% - files_checked searches for these files in the /eeg folder within each
% subject folder
init.files_checked.via11 = {sprintf('sub-via*_ses-via11_task-%s_eeg.bdf',init.task)};
%init.files_checked.via15 = init.files_checked.via11;


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


%Coloumns to include from sub_info_table
% - only include these participant info variables (columns) in participants.tsv
% - if no variables are listed, all variables are added to the participants.tsv
init.participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};


%Path to stimulation files to include in /stimuli directory in bids_dir
% - OPTIONAL
init.stim_files.via11 = {'/home/simonyj/EEG_ASSR_reg/click_40_regular.wav'};
%init.stim_files.via15 = {'/home/simonyj/EEG_MMN/std.wav','/home/simonyj/EEG_MMN/dev1.wav',...
%            '/home/simonyj/EEG_MMN/dev2.wav','/home/simonyj/EEG_MMN/dev3.wav'};

%Whether to include a scans.tsv file
init.include_scans_tsv = true;

%Whether to include events.tsv
% - events MAY be either stimuli presented to the participant or participant responses
% - events.tsv file are generated based on the events field in the bdf 
%file header by default. 
% - refer to the events part of section "Generate BIDS structure and files"
%in this script for any custom changes to this events.tsv file outside the 
%events in the bdf file header
init.include_events_tsv = true; 

%Should channels.tsv be loacted in bids_dir or subject folders
% - if in bids_dir, according to the inheritance principle, the channels
%files are general for all subjects and sessions
% - this functionality is needed for mulitple tasks in bids_dir
init.channels_in_sub_dir = false; %false -> channels.tsv will be located in bids_dir
init.include_task_name = false; %true -> name of file will be e.g task-MMN_channels.tsv

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
init.dataset_description.DatasetType = 'raw'; 
init.dataset_description.EthicsApprovals = {'The local Ethical Committee (Protocol number: H 16043682)','The Danish Data Protection Agency (IDnumber RHP-2017-003, I-suite no. 05333)'}; % - OPTIONAL

%txt file paths to be read
% - OPTIONAL
init.event_txt_file = fullfile('/home/simonyj/EEG_ASSR_reg','ASSR_events.txt'); % txt file with information about events but not the events itself. This includes trigger values or notes about the events in general. Should have a VERY specific format, check other events.txt in github repo
init.instructions_txt = fullfile('/home/simonyj/EEG_ASSR_reg','ASSR_reg_instructions.txt'); %txt file with instructions. Should be instructions combined in one single line of a txt file. 
%init.participants_var_txt = fullfile('/home/simonyj/EEG_ASSR_reg','participants_variables.txt'); %txt file with a description about the variables (columns) in participants.tsv. This could also include levels for categorical variables or units for variables. Has specific format, check example file on github repo.

%Extra notes to go into events.json as a field called "extra_notes"
% - OPTIONAL
init.extra_notes = ' ';

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
    cfg.method    = 'copy'; %if 'copy' the eeg files are only copied. If 'convert' the input data is converted to BrainVision data format before stored in bids_dir
    cfg.sesindx = sesindx;
    cfg.subindx = subindx;
    
    %Configure inputs and add it to the cfg struct. The cfg struct is unique
    %for every iteration in this loop, i.e. for every session and subject
    cfg = configure_input(cfg,input);
    
    %Specify the information for the participants.tsv file
    cfg.participants = make_participants_cfg(cfg,input);
    
    %Provide the mnemonic and long description of the task
    cfg.TaskName        = init.task;
    cfg.TaskDescription = '????';

    %Specify some general information that will be added to the eeg.json file
    cfg.eeg.InstitutionName             = 'Centre for Functional and Diagnostic Imagning and Research, Danish Research Center for Magnetic Resonance, Amager and Hvidovre hospital'; % - RECOMMENDED
    cfg.eeg.InstitutionAddress          = 'Kettegard Allé 30, DK-2650 Hvidovre, Denmark'; % - RECOMMENDED
    
    %EEG specific configs saved in *_eeg.json file 
    % - refer to the bids-specification about Electroencephalography for a
    %detailed description of the fields to be specified in eeg.json
    cfg.eeg.PowerLineFrequency    = 50;
    cfg.eeg.EEGReference          = 'Common Mode Sense (CMS) and Driven Right Leg (DRL)'; 

    cfg.eeg.Manufacturer          = 'Biosemi'; % - RECOMMENDED
    cfg.eeg.ManufacturersModelName = '????'; % - RECOMMENDED
    cfg.eeg.SoftwareVersions      = '????'; % - RECOMMENDED
    %cfg.eeg.CogPOID               = '????'; % - RECOMMENDED
    cfg.eeg.DeviceSerialNumber    = '????'; % - RECOMMENDED
    
    %software filters
    swf.filter_characteristic = '????';
    swf.filter_parameter = 10;
    swf3.filter_characteristic = '????';
    swf3.filter_parameter = 100;
    cfg.eeg.SoftwareFilters.Filter1       = swf;
    cfg.eeg.SoftwareFilters.Filter3       = swf3;
    
    %manufacturer information
    cfg.eeg.CapManufacturer = 'Biosemi'; % - RECOMMENDED
    cfg.eeg.CapManufacturersModelName = '????'; % - RECOMMENDED
    cfg.eeg.EEGPlacementScheme = 'radial'; % - RECOMMENDED

    
    %%%%%%%  HEADER  %%%%%%%%%  
    % - OPTIONAL
    %this part can be removed if no additional channel info is needed from
    %the header of the eeg files. First the header of the eeg file is read 
    %and then additional channel information is added. Modififying the 
    %cfg.hdr will not change anything in the eeg file, only in the custom 
    %temporary header struct created here which is to be parsed to the 
    %function that generates the bids files.
    % - look in the channels.tsv to see what rows need extra information
    
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
    % - OPTIONAL
    %This part can be removed if no additional events should be added to
    %the events.tsv. If this part is removed, the only things that go into
    %the events.tsv file is the events read in the eeg file header.
    %First the header of the eeg file is read and then additional 
    %events can be added. Modififying the event_struct will not 
    %change anything in the eeg file, only in the temporarily created 
    %event_struct that is parsed to the function that generates the bids files
    %Note: the example below might not be make any sense for you depdending
    %on the events present in your task. Please study what the event_struct
    %looks like before adding things to it.
    
    if init.include_events_tsv %only include the events.tsv file if specified in the init struct above

        %read the events of the bdf file
        event_struct = ft_read_event(cfg.dataset);

        %extract the sampling frequency from somewhere
        fs = cfg.hdr.Fs;  %e.g. 4096
        delay = 38;

        bdf_event_samples = [event_struct.sample];   
        conditionlabels = cell(1,120);
        conditionlabels{1} = 'click';
        trl2(1,1)=round(bdf_event_samples(1)+(38/1000)*fs);
        trl2(1,2)=round(bdf_event_samples(1)+1000+(38/1000)*fs); %the first two terms in this definition is arbitrary
        table_sf{1} = input.bids_stim_file_name.(input.ses{sesindx}){1};

        for k = 2:120
            trl2(k,1)=round(trl2(k-1,1)+3*fs);
            trl2(k,2)=round(trl2(k-1,2)+3*fs);
            conditionlabels{k}='click';
            table_sf{k} = input.bids_stim_file_name.(input.ses{sesindx}){1};
        end

        bdf_event_table = struct2table(event_struct); 
        type = repmat({'STATUS'},length(conditionlabels),1) ;
        value = cell(length(conditionlabels),1);
        offset = cell(length(conditionlabels),1); %keep this variable
        duration = num2cell(ones(length(conditionlabels),1));
        sample = trl2(:,1);

        generated_event_table = table(type,sample,value,offset,duration);
        event_table = [bdf_event_table;generated_event_table];

        %event_table.stim_file = [cell(length(event_struct),1); repmat(bids_stim_file_name.(input.ses{sesindx})(1),length(conditionlabels),1)];
        event_table.stim_file = [cell(length(event_struct),1); table_sf'];
        event_table.delay = ones(length(event_struct)+length(conditionlabels),1)*delay/1000;
        event_table.conditionlabel = [cell(length(event_struct),1); conditionlabels(:)];

        cfg.events = table2struct(event_table);
        cfg.keep_events_order = true; %should the events be sorted according to sample or should it keep the order in cfg.events?
    end
    
    
    %%%%%%% MAKING BIDS DATASET FOR THE CURRENT SUBJECT IN LOOP %%%%%%% 
    
    %make bids dataset with the cfg struct
    data2bids(cfg);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %write events.json
    if input.init.write_events %if events.tsv should be written, so should events.json
        
        %description, units, or categorical levels of variables (columns) in events.tsv
        %this information goes into events.json
        cfg.event_json_struct.onset.Description = 'Onset of stimuli. The onset of the sound being played for the subject and not the onset of epoch';
        cfg.event_json_struct.onset.Units = 's';

        cfg.event_json_struct.duration.Description = 'Duration of stimuli';
        cfg.event_json_struct.duration.Units = 's';

        cfg.event_json_struct.sample.Description = '????';
        cfg.event_json_struct.sample.Units = '????';

        cfg.event_json_struct.type.Description = '????';
        cfg.event_json_struct.type.Levels.STATUS = 'STATUS type';
        cfg.event_json_struct.type.Levels.Epoch = 'Epoch type';
        cfg.event_json_struct.type.Levels.CM_in_range = 'CM_in_range type';

        cfg.event_json_struct.delay.Description = 'Delay between the trigger and when the sound is actually played in the headphones of 37 ms';
        cfg.event_json_struct.delay.Units = 's';

        cfg.event_json_struct.conditionlabel.Description = '????';
        cfg.event_json_struct.conditionlabel.Levels.Int_1 = '????';
        cfg.event_json_struct.conditionlabel.Levels.Int_2 = '????';

        cfg.event_json_struct.rand_ISI.Description = '????';
        cfg.event_json_struct.rand_ISI.Units = '????';

        cfg.event_json_struct.start_samples.Description = '????';
        cfg.event_json_struct.start_samples.Units = '????';

        cfg.event_json_struct.StimulusPresentation.OperatingSystem = '????';
        cfg.event_json_struct.StimulusPresentation.SoftwareName = '????';
        %cfg.TaskEventsDescription.StimulusPresentation.SoftwareRRID = '????';
        cfg.event_json_struct.StimulusPresentation.SoftwareVersion = '????';
        %cfg.TaskEventsDescription.StimulusPresentation.code = '????';

        %write the file 
        fn = fieldnames(cfg.event_json_struct);
        cfg.event_json_struct = keepfields(cfg.event_json_struct, fn);
        ft_write_json(cfg.event_json_file, cfg.event_json_struct);
        fprintf('writing %s\n',cfg.event_json_file)
    end
    
    %Keep the below if statement
    %make sure not to write events.json file more than once if it is to be
    %placed in bids_dir, e.i if sub-XXX is in file name the events.json 
    %should not be written next iteration of subject loop as only ONE
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


%% Write a readme and .bidsignore file 
% CHANGES NEEDED IN THIS SECTION
% - RECOMMENDED

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


%% participants.json from .txt file
%NO CHANGES NEEDED IN THIS SECTION

%All participant info is assumed to be identical for all tasks and sessions
if strcmp(input.run_mode,'new_BIDS') && isfield(init,'participants_var_txt')
    write_participants_json(init)
end


%% Copy scripts for bids dataset creation to the /code directory 
% NO CHANGES NEEDED IN THIS SECTION

%the path of the current script
this_file_path = mfilename('fullpath');
this_file_path = strcat(this_file_path,'.m');

%add paths to sxripts that should be added to /code directory in bids dataset
code_file_paths = {this_file_path};
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/move_warnings_last.py');
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/change_json_int_keys.py');
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/EEG2BIDS_job.sh');
code_file_paths{end+1} = fullfile(init.EEG2BIDS_tool_dir,'/src/EEG2BIDS.sh');

if strcmp(input.run_mode,'new_BIDS')
    cp_code2bids(init,code_file_paths)
end



%% Print an ending statement
% NO CHANGES NEEDED IN THIS SECTION

if strcmp(input.run_mode,'new_BIDS')
    fprintf('Created BIDS dataset in: %s\n\n',init.bids_dir)
else
    fprintf('Added subjects to the BIDS dataset in: %s\n\n',init.bids_dir)
end


end 


