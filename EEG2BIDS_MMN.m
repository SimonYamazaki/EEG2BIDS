function EEG2BIDS_MMN(varargin)

addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')
addpath('/home/simonyj/EEG2BIDS/utils/')

%% Setup  

data_dir.via11 = '/home/simonyj/EEG_MMN';
data_dir.via15 = '/home/simonyj/EEG_MMN';
bids_dir = varargin{1};
%bids_dir = '/home/simonyj/EEG_BIDS_MMN';
EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';

%task Definition: Each task has a unique label that MUST only consist of letters and/or numbers (other characters, including spaces and underscores, are not allowed).
task = 'MMN';

%trigger start event value and the number of expected event values
trig_start_value = 65281;
n_trig_start = 1;

%search pattern for data files
data_file.via11 = '*_MMN.bdf';
data_file.via15 = '*_MMN.bdf';
nono_keywords_in_filename = {'Flanker','ASSR'};

%search pattern for other files that must exist along side the data file
must_exist_files = {'*_triggers.mat'}; %currently searches data_dir for these files

%file to check for to determine existing subjects
files_checked = {'eeg.bdf','eeg.json','events.tsv','channels.tsv'};

%only include these participant info variables
participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

% parse a subject info table from databse for participant information
sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
id_col_name = 'famlbnr';

%path to stimulation files to include in /stimuli in bids root dir
stim_files = {'/home/simonyj/EEG_MMN/std.wav','/home/simonyj/EEG_MMN/dev1.wav',...
            '/home/simonyj/EEG_MMN/dev2.wav','/home/simonyj/EEG_MMN/dev3.wav'};

%txt file paths to be read
event_txt_file = fullfile(data_dir.via11,'MMN_events.txt');
instructions_txt = fullfile(data_dir.via11,'MMN_instructions.txt');
participants_var_txt = fullfile(data_dir.via11,'participants_variables.txt');


%% Configure the setup

sub_info_table = readtable(sub_info_table_path);
via_id = sub_info_table.(id_col_name);

this_file_path = mfilename('fullpath');
this_file_path = strcat(this_file_path,'.m');

[sub,ses,bdf_file_names] = define_sub_ses_bdf(data_dir, varargin, data_file, via_id, this_file_path, nono_keywords_in_filename);

if exist('must_exist_files','var')
    [subs_with_additional_files,additional_file_names] = search_must_exist_files(data_dir,via_id,must_exist_files);
    cmp_and_print_subs_with_file(sub,subs_with_additional_files,must_exist_files,ses)
end

finished_ses = false(1,length(ses));
ses_run = false(1,length(ses));
ses_add = false(1,length(ses));

for s = 1:length(ses)
    existing_sub = find_existing_subs(bids_dir,files_checked,ses(s));
        
    if length(varargin)==1
        sub.(ses{s}) = sub.(ses{s})(~ismember(sub.(ses{s}),existing_sub.(ses{s})));
    
        finished_ses(s) = isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s}));
        ses_run(s) = ~isempty(sub.(ses{s})) && isempty(existing_sub.(ses{s}));
        ses_add(s) = ~isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s}));
    else
        finished_ses(s) = false;
        ses_run(s) = ~isempty(sub.(ses{s})) && isempty(existing_sub.(ses{s}));
        ses_add(s) = ~isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s}));
    end
end

assert( all(not(finished_ses)), 'All relevant subject files are moved to BIDS data structure in all sessions. Add more subject files to the data_dir or run EEG2BIDS.sh for a specific subject.')
if any(ses_run)
    fprintf('Creating new BIDS dataset from subject files \n')
    run_mode = 'new_BIDS';
elseif any(ses_add)
    ses_to_add = ses(ses_add);
    for s = 1:length(ses_to_add)
        fprintf('Moving subject %s files into BIDS data structure for session %s\n',sub.(ses_to_add{s}){:},ses_to_add{s})
    end
    run_mode = 'add_sub';
end

%Copy the stimulation files to /stim direcotry
if exist('stim_files','var')
    if strcmp(run_mode,'new_BIDS')
        bids_stim_file_path = cell(length(stim_files),1);
        stim_dir = fullfile(bids_dir,'/stimuli');
        if not(isfolder(stim_dir))
            mkdir(stim_dir)
        end
    
        for sf=1:length(stim_files)
            [folder,name,ext] = fileparts(stim_files{sf});
            bids_stim_file_name{sf} = strcat(name,ext);
            bids_stim_file_path{sf} = fullfile(stim_dir,bids_stim_file_name{sf});
            copyfile( stim_files{sf}, bids_stim_file_path{sf}, 'f')
        end
    end
end

%% Generate BIDS structure and files

%%%%%% Use data2bids function on each subject %%%%%%%%

% for more information on data2bids function see: 
% https://github.com/fieldtrip/fieldtrip/blob/master/data2bids.m

if not(isfolder(bids_dir))
    mkdir(bids_dir)
end

%read instructions into cell 
if exist('instructions_txt','var')
    InstructionsC = read_txt(instructions_txt);
end

for sesindx=1:numel(ses)
    for subindx=1:numel(sub.(ses{sesindx}))
        
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy';
    cfg.datatype  = 'eeg';

    % specify the output directory
    cfg.bidsroot  = bids_dir;
    if ~strcmp(ses{sesindx},'None')
        cfg.ses       = ses{sesindx};
    end
    % get subject via ID 
    cfg.sub       = sub.(ses{sesindx}){subindx};
    sub_int       = str2num(cfg.sub);
    
    cfg.include_scans = false;
    
    % define data file for current subject
    if isstruct(data_dir)
        cfg.dataset   = char(fullfile(data_dir.(ses{sesindx}),bdf_file_names.(ses{sesindx}){subindx}));
    else
        cfg.dataset   = char(fullfile(data_dir,bdf_file_names.(ses{sesindx}){subindx}));
    end
    
    if strcmp(run_mode,'new_BIDS')
        cfg.dataset_description.BIDSVersion = '1.6';
        cfg.dataset_description.Name = sprintf('%s EEG',task);
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

    if exist('InstructionsC','var')
        cfg.eeg.Instructions          = InstructionsC{1};
    end
    
    swf.filter_characteristic = '????';
    swf.filter_parameter = 10;
    swf3.filter_characteristic = '????';
    swf3.filter_parameter = 100;

    cfg.eeg.SoftwareFilters.Filter1       = swf;
    cfg.eeg.SoftwareFilters.Filter3       = swf3;

    cfg.eeg.CapManufacturer = 'Biosemi';
    cfg.eeg.CapManufacturersModelName = '????';
    cfg.eeg.EEGPlacementScheme = 'radial';

    %%%%%%%  HEADER  %%%%%%%%%
    cfg.hdr = ft_read_header(cfg.dataset);
    EXG_chan_types = cell(9,1);
    EXG_chan_types(:) = {'EMG'};
    cfg.hdr.chantype(end-8:end) = EXG_chan_types;
    EXG_chan_units = cell(9,1);
    EXG_chan_units(:) = {'uV'};
    cfg.hdr.chanunit(end-8:end) = EXG_chan_units;

    %%%%%%%%  EVENTS %%%%%%%%
    event_struct = ft_read_event(cfg.dataset);
    
    %check that the .bdf file only contains the expected amount of events
    if exist('trig_start_value','var')
        if sum([event_struct.value]==trig_start_value)~=n_trig_start
            fprintf('Subject %s has more trigger start events than expected. Check whether the data file includes tasks other than %s.',cfg.sub,task)
            %fprintf('WARNING: Not including subject %s in the bids structure as the .bdf file includes more events than expected',cfg.sub,task)
        end
    end
    
    fs = cfg.hdr.Fs;  %e.g. 4096
    delay = 37;
    
    load(sprintf('%s/subject_%s_MMN_triggers.mat',data_dir.(ses{sesindx}),cfg.sub));

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
    S.conditionlabels{1,:} = 'std';
    duration_vec = zeros(length(S.conditionlabels),1);
    duration_vec(1) = 50/1000;
    table_sf = cell(length(S.conditionlabels),1);
    trig=round(start_samples/(44100/4096));

    for i = 2:length(trig)
        S.trl(i,1)=S.trl(1,1)+trig(i);
        if mmn_codes(i)==1
            S.conditionlabels{i,:}= 'std';
            duration_vec(i) = 50/1000;
            table_sf{i} = bids_stim_file_name{1};
        elseif mmn_codes(i) ==2
            S.conditionlabels{i,:}= 'dev1';
            duration_vec(i) = 50/1000;
            table_sf{i} = bids_stim_file_name{2};
        elseif mmn_codes(i) ==3
            S.conditionlabels{i,:}='dev2';
            duration_vec(i) = 100/1000;
            table_sf{i} = bids_stim_file_name{3};
        elseif mmn_codes(i) ==4
            S.conditionlabels{i,:}='dev3';
            duration_vec(i) = 100/1000;
            table_sf{i} = bids_stim_file_name{4};
        end
    end
    
    bdf_event_table = struct2table(event_struct); 
    type = repmat({'STATUS'},length(S.conditionlabels),1) ;
    value = cell(length(S.conditionlabels),1);
    offset = cell(length(S.conditionlabels),1); %keep this variable
    duration = num2cell(duration_vec)';
    sample = S.trl(:,1);
    
    generated_event_table = table(type,sample,value,offset,duration);
    event_table = [bdf_event_table;generated_event_table];

    event_table.stim_file = [cell(length(event_struct),1); table_sf'];
    event_table.delay = ones(length(event_struct)+length(S.conditionlabels),1)*delay/1000;
    event_table.conditionlabel = [cell(length(event_struct),1); S.conditionlabels(:)];
    event_table.rand_ISI = [cell(length(event_struct),1); num2cell(rand_ISI')];
    event_table.start_samples = [cell(length(event_struct),1); num2cell(start_samples')];

    cfg.events = table2struct(event_table);
    cfg.keep_events_order = true; %should the events be sorted according to sample or should it keep the order?

    
    data2bids(cfg);
    
    end
end


%% Write events.json 

if strcmp(run_mode,'new_BIDS')

    filename = fullfile(bids_dir, sprintf('task-%s_events.json',task));
    
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

    if exist('event_txt_file','var')
        %read from txt 
        eventsC = read_txt(event_txt_file);
        %add value and notes to the event.json  
        extra_notes = ' The variables from subject_*SUB_ID*_MMN_triggers.mat files are added to the events.tsv files as start_sample -> start_sample, rand_ISI -> rand_ISI, mmn-codes -> conditionlabels.';
        cfg.TaskEventsDescription = read_events_txt(cfg.TaskEventsDescription,eventsC,extra_notes);
    end
    
    non_described_vars = check_described_variables_in_tsv(bids_dir,cfg.TaskEventsDescription,sub,'events.tsv');
    
    fn = fieldnames(cfg.TaskEventsDescription);
    TaskEventsDescription_settings = keepfields(cfg.TaskEventsDescription, fn);
    ft_write_json(filename, TaskEventsDescription_settings);
end




%% Write participants.json from .txt file

if strcmp(run_mode,'new_BIDS')
    
    %any additional info to include in json
    cfg.ParticipantsDescription.participant_id.Description = 'The identification number of the subject';

    %read from txt 
    participants_var = read_txt(participants_var_txt);
    cfg.ParticipantsDescription = read_participants_var_txt(cfg.ParticipantsDescription,participants_var,participant_info_include);
    
    non_described_vars = check_described_variables_in_tsv(bids_dir,cfg.ParticipantsDescription,sub,'participants.tsv');
    
    %write the file 
    filename = fullfile(bids_dir, 'participants.json');
    
    fn = fieldnames(cfg.ParticipantsDescription);
    ParticipantsDescription_settings = keepfields(cfg.ParticipantsDescription, fn);
    ft_write_json(filename, ParticipantsDescription_settings);
end


%% Write channels.json file 

if strcmp(run_mode,'new_BIDS')
    filename = fullfile(cfg.bidsroot, sprintf('task-%s_channels.json',task));
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



%% Copy this script to the /code directory in BIDS structure 

code_dir = fullfile(bids_dir,'/code');

if not(isfolder(code_dir))
    mkdir(code_dir)
end

[folder,name,ext]=fileparts(this_file_path);
copyfile(this_file_path, fullfile(code_dir,strcat(name,ext)), 'f')

%also copy BIDS validator, json fix scripts and job script 
if strcmp(run_mode,'new_BIDS')
    %copyfile(fullfile(EEG2BIDS_tool_dir,'/BIDS_validator_EEG.py'), fullfile(code_dir,'/BIDS_validator_EEG.py'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/change_json_int_keys.py'), fullfile(code_dir,'/change_json_int_keys.py'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG2BIDS_job.sh'), fullfile(code_dir,'/EEG2BIDS_job.sh'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG2BIDS.sh'), fullfile(code_dir,'/EEG2BIDS.sh'), 'f')
end


%% Write a readme and .bidsignore file 

if strcmp(run_mode,'new_BIDS')
    %write a readme about extra information
    fileID = fopen(fullfile(bids_dir,'README'),'w');
    fprintf(fileID,'Something, something');
    fclose(fileID);
    
    %write .bidsignore file
    fileID = fopen(fullfile(bids_dir,'.bidsignore'),'w');
    fprintf(fileID,'/cluster_submissions/');
    fclose(fileID);
end


%% Print an ending statement

if strcmp(run_mode,'new_BIDS')
    fprintf('Created BIDS dataset in: %s\n\n',bids_dir)
else
    fprintf('Added subjects to the BIDS dataset in: %s\n\n',bids_dir)
end


end 


