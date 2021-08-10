function EEG2BIDS_ASSR_reg(varargin)

addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')
addpath('/home/simonyj/EEG2BIDS/utils/')

%% Setup  

data_dir.via11 = '/home/simonyj/EEG_ASSR_reg';
data_dir.via15 = '/home/simonyj/EEG_ASSR_reg';
bids_dir = '/home/simonyj/EEG_BIDS_ASSR_reg';
EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';
task = 'ASSR_reg';

%trigger start event value and the number of expected event values
trig_start_value = 65281;
n_trig_start = 1;

%search pattern for data files
data_file = '*_ASSR_reg.bdf'; %only replace the subject ID with '*'
nono_keywords_in_filename = {'Flanker','irreg','MMN'};

%search pattern for other files that must exist along side the data file
%must_exist_files = {'*_triggers.mat'}; %currently searches data_dir for these files

%file to check for to determine existing subjects
files_checked = {'eeg.bdf','eeg.json','events.tsv','channels.tsv'};

%only include these participant info variables
participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

% parse a subject info table from databse for participant information
sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
id_col_name = 'famlbnr';

%path to stimulation files to include in /stimuli in bids root dir
stim_files = {'/home/simonyj/EEG2BIDS/BIDS_validator_EEG.py','/home/simonyj/EEG2BIDS/BIDS_validator_EEG.py'};

%txt file paths to be read
event_txt_file = fullfile(data_dir.via11,'ASSR_events.txt');
instructions_txt = fullfile(data_dir.via11,'ASSR_reg_instructions.txt');
participants_var_txt = fullfile(data_dir.via11,'participants_variables.txt');


%% Configure the setup

sub_info_table = readtable(sub_info_table_path);
via_id = sub_info_table.(id_col_name);

this_file_path = mfilename('fullpath');
this_file_path = strcat(this_file_path,'.m');

[sub,ses,bdf_file_names] = define_sub_ses_bdf(data_dir,varargin,data_file,via_id,nono_keywords_in_filename);

if exist('must_exist_files','var')
    subs_with_additional_files = search_must_exist_files(data_dir,via_id,must_exist_files);
end

finished_ses = false(1,length(ses));
ses_run = false(1,length(ses));
ses_add = false(1,length(ses));

for s = 1:length(ses)
    existing_sub.(ses{s}) = find_existing_subs(bids_dir,files_checked,ses(s));

    if exist('subs_with_additional_files','var')
        cmp_and_print_subs_with_file(sub,subs_with_additional_files,ses(s))
    end
        
    if isempty(varargin)
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
    %trl2(1,3)=-fs;
    
    for k = 2:120
        trl2(k,1)=round(trl2(k-1,1)+3*fs);
        trl2(k,2)=round(trl2(k-1,2)+3*fs);
        %trl2(k,3)=-fs;
        conditionlabels{k}='click';
    end
    
    bdf_event_table = struct2table(event_struct); 
    type = repmat({'STATUS'},length(conditionlabels),1) ;
    value = cell(length(conditionlabels),1);
    offset = cell(length(conditionlabels),1);
    duration = num2cell(ones(length(conditionlabels),1) * (trl2(1,2)-trl2(1,1)) );
    sample = trl2(:,1);
    
    generated_event_table = table(type,sample,value,offset,duration);
    event_table = [bdf_event_table;generated_event_table];
    
    event_table.delay = ones(length(event_struct)+length(conditionlabels),1)*delay/1000;
    event_table.conditionlabel = [cell(length(event_struct),1); conditionlabels(:)];

    cfg.events = table2struct(event_table);

    
    data2bids(cfg);
    
    end
end


%% Write events.json 

if strcmp(run_mode,'new_BIDS')

    filename = fullfile(bids_dir, sprintf('task-%s_events.json',task));
    
    cfg.TaskEventsDescription.onset.Description = 'Onset of stimuli';
    cfg.TaskEventsDescription.onset.Units = 's';

    cfg.TaskEventsDescription.duration.Description = 'Duration of stimuli';
    cfg.TaskEventsDescription.duration.Units = 's';

    cfg.TaskEventsDescription.sample.Description = '????';
    cfg.TaskEventsDescription.sample.Units = 's';

    cfg.TaskEventsDescription.type.Description = '????';
    cfg.TaskEventsDescription.type.Levels.STATUS = 'STATUS type';
    cfg.TaskEventsDescription.type.Levels.Epoch = 'Epoch type';
    cfg.TaskEventsDescription.type.Levels.CM_in_range = 'CM_in_range type';
    
    cfg.TaskEventsDescription.delay.Description = 'Delay between the trigger and when the sound is actually played in the headphones of 37 ms, see also the file trigger_delay';
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
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    ChannelsDescription_settings = keepfields(cfg.ChannelsDescription, fn);
    ft_write_json(filename, ChannelsDescription_settings);
end


%% Write electrode.tsv file from biosemi excel file coordinates 


if strcmp(run_mode,'new_BIDS')
    
    elec_tab = readtable('/home/simonyj/EEG_flanker/Cap_coords_all.xls','Sheet','128-chan');
    [r,c] = size(elec_tab);
    elec_tab_clean = rmmissing(elec_tab,2,'MinNumMissing',r);
    ft_write_tsv(fullfile(bids_dir,sprintf('task-%s_desc-original-biosemi_electrode_table.tsv',task)), elec_tab_clean)
    
    elec_tab_clean.Properties.VariableNames(strcmp(elec_tab_clean.Properties.VariableNames,'Electrode')) = {'Name'};
    elec_tab_clean.Properties.VariableNames(strcmp(elec_tab_clean.Properties.VariableNames,'x_RSin_Cos_')) = {'x'};
    elec_tab_clean.Properties.VariableNames(strcmp(elec_tab_clean.Properties.VariableNames,'y_RSin_Sin_')) = {'y'};
    elec_tab_clean.Properties.VariableNames(strcmp(elec_tab_clean.Properties.VariableNames,'z_RCos_')) = {'z'};
    
    var_names =  {{'Name','x','y','z'}, {'Name','x__Inclination_','x__Azimuth_'},{'Name','sph_theta','sph_phi'}};
    coord_names = {'biosemi-cartesian','biosemi-spherical','biosemi-EEGLab'};
    
    for e = 1:length(coord_names)
        coord_str = strrep(coord_names{e},'-','_');
        elec = elec_tab_clean(:,var_names{e});
        ft_write_tsv(fullfile(bids_dir,sprintf('task-%s_desc-%s_electrodes.tsv',task,coord_names{e})), elec)
        
        %write coordsysmtem.json file 
        tab = readcell('/home/simonyj/EEG_flanker/Cap_coords_all.xls','Sheet','128-chan');
        filename = fullfile(bids_dir, sprintf('task-%s_desc-%s_coordsystem.json',task,coord_names{e}));

        cols_oi = [5,1,11];
        max_row = [11,13, 8];
        coord_info = tab(1:max_row(e),cols_oi(e));
        missing_idx = find(cell2mat(cellfun(@(x) length(x)==1 && x==1, cellfun(@ismissing, coord_info,'UniformOutput',0), 'UniformOutput',0)));

        cfg.(coord_str).IntendedFor = sprintf('task-%s_desc-%s_electrodes.tsv',task,coord_names{e}');
        EEGCoordinateSystemDescription = coord_info{1:missing_idx(1)-1};

        if strcmp(coord_names{e},'biosemi-cartesian')
            cfg.(coord_str).EEGCoordinateSystem = '????';
            cfg.(coord_str).EEGCoordinateUnits = 'mm';
            EEGCoordinateSystemDescription = strcat(EEGCoordinateSystemDescription,'. Coordinates are given assuming a head circumference of 55 cm.');
            
        else
            cfg.(coord_str).EEGCoordinateSystem = '????';
            cfg.(coord_str).Info.(var_names{e}{2}) = strcat(coord_info{missing_idx(1)+1:missing_idx(2)-1});
            cfg.(coord_str).Info.(var_names{e}{3}) = strcat(coord_info{missing_idx(2)+1:end}); 
        end

        cfg.(coord_str).EEGCoordinateSystemDescription = strcat(EEGCoordinateSystemDescription,' Coordinate system info gathered from https://www.biosemi.com/headcap.htm');
        
        fn = fieldnames(cfg.(coord_str));
        fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
        Coordsystem_settings = keepfields(cfg.(coord_str), fn);
        ft_write_json(filename, Coordsystem_settings);
    end
end



%% Write electrode.tsv file from channel locations file by Melissa 

if strcmp(run_mode,'new_BIDS')
    
    load('/mrhome/simonyj/EEG_flanker/chanlocs.mat')

    chanloc_table = struct2table(chanlocs);
    ft_write_tsv(fullfile(bids_dir,sprintf('task-%s_desc-original-chanloc_table.tsv',task)), chanloc_table)
    
    chanloc_table.Properties.VariableNames(strcmp(chanloc_table.Properties.VariableNames,'labels')) = {'Name'};
    
    var_names =  {{'urchan','Name','X','Y','Z'}, {'urchan','Name','sph_theta','sph_phi','sph_radius'}};
    coord_names = {'M-cartesian','M-spherical'};
    
    for e = 1:length(coord_names)
        coord_str = strrep(coord_names{e},'-','_');
        elec = chanloc_table(:,var_names{e});
        ft_write_tsv(fullfile(bids_dir,sprintf('task-%s_desc-%s_electrodes.tsv',task,coord_names{e})), elec)
        
        %write coordsysmtem.json file 
        filename = fullfile(bids_dir, sprintf('task-%s_desc-%s_coordsystem.json',task,coord_names{e}));

        cfg.(coord_str).IntendedFor = sprintf('task-%s_desc-%s_electrodes.tsv',task,coord_names{e}');

        if strcmp(coord_names{e},'M-cartesian')
            cfg.(coord_str).EEGCoordinateSystem = '????';
            cfg.(coord_str).EEGCoordinateUnits = 'Normalized';
            cfg.(coord_str).EEGCoordinateSystemDescription = 'Cartesian coordinate system with 1 representing the radius of the subject head. Subject head is assumed spherical.';
        else
            cfg.(coord_str).EEGCoordinateSystem = '????';
            cfg.(coord_str).EEGCoordinateUnits = 'Normalized to radius 1';
            cfg.(coord_str).EEGCoordinateSystemDescription = 'Spherical coordinate system. Subject head is assumed spherical.';
        end
 
        fn = fieldnames(cfg.(coord_str));
        fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
        Coordsystem_settings = keepfields(cfg.(coord_str), fn);
        ft_write_json(filename, Coordsystem_settings);
    end
        
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
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG_MMN_job.sh'), fullfile(code_dir,'/EEG_MMN_job.sh'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG2BIDS.sh'), fullfile(code_dir,'/EEG2BIDS.sh'), 'f')
end


%% Copy the stimulation files to /stim direcotry

if exist('stim_files','var')

    stim_dir = fullfile(bids_dir,'/stimuli');

    if not(isfolder(stim_dir))
        mkdir(stim_dir)
    end

    if strcmp(run_mode,'new_BIDS')
        for sf=1:length(stim_files)
            [folder,name,ext] = fileparts(stim_files{sf});
            copyfile( stim_files{sf}, fullfile(stim_dir,strcat(name,ext)), 'f')
        end
    end

end

%% Print an ending statement

if strcmp(run_mode,'new_BIDS')
    fprintf('Successfully created BIDS dataset in: %s\n\n',bids_dir)
else
    fprintf('Successfully added subjects to the BIDS dataset in: %s\n\n',bids_dir)
end

end
