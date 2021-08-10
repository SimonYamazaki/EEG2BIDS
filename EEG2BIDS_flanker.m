clear;
addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')
addpath('/home/simonyj/EEG2BIDS/utils/')


%% Setup  

data_dir.via11 = '/home/simonyj/EEG_flanker';
data_dir.via15 = '/home/simonyj/EEG_flanker';
bids_dir = '/home/simonyj/EEG_BIDS_flanker';
EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';
task = 'Flanker';

n_trig_start = 400;

nono_keywords_in_filename = {'MMN','ASSR'};
files_checked = {'eeg.bdf','eeg.json','events.tsv','channels.tsv'};

%only include these participant info variables
participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

% parse a subject info table from databse for participant information
sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';

behav_path = '/mnt/projects/VIA11/EEG/Anna/Flanker/Input_behavdata_Excel/Flankerbehav090119.xls';
behav_col_names_path = '/mnt/projects/VIA11/EEG/Data/Flanker_47condition/EEG_Flanker.txt';

event_txt_file = 'Flanker_events.txt';
instructions_txt = 'Flanker_instructions.txt';
participants_var_txt = 'participants_variables.txt';

%% Configure the setup

if isstruct(data_dir)
    ses = fieldnames(data_dir);
else
    ses = {'None'};
end

sub_info_table = readtable(sub_info_table_path);
total_cols = width(sub_info_table);
col_names = sub_info_table.Properties.VariableNames;
via_id = sub_info_table.famlbnr;
sub_info_table = table2cell(sub_info_table);

[sub,bdf_file_names] = find_sub_ids(data_dir,'*_Flanker.bdf',via_id,nono_keywords_in_filename);
[sub_additional,additional_file_names] = find_sub_ids(data_dir,'*.edat2',via_id);

%read instructions 
InstructionsC = read_txt(fullfile(data_dir.via11,instructions_txt));

finished_ses = false(1,length(ses));
ses_run = false(1,length(ses));
ses_add = false(1,length(ses));

for s = 1:length(ses)
    
    if isequal(sub.(ses{s}),sub_additional.(ses{s}))
        fprintf('\nAll subjects with .bdf files also have trigger files in session %s\n',ses{s})
    elseif length(sub.(ses{s}))==length(sub_additional.(ses{s})) && ~isequal(sub,sub_additional.(ses{s}))
        fprintf('Did not find match between subjects with .bdf files and subjects with trigger .mat files. Check if subject ID search pattern is correct for session %s\n',ses{s})
    elseif length(sub.(ses{s}))>length(sub_additional.(ses{s}))
        fprintf('Subject %s has .bdf file but are missing a trigger file in session %s\n',sub{~ismember(sub.(ses{s}),sub_additional.(ses{s}))},ses{s} )
    elseif length(sub.(ses{s}))<length(sub_additional.(ses{s}))
        fprintf('Subject %s has trigger file but are missing .bdf file in session %s\n',sub_additional.(ses{s}){~ismember(sub_additional.(ses{s}),sub.(ses{s}))},ses{s} )
    end
    
    existing_sub.(ses{s}) = find_existing_subs(bids_dir,files_checked,ses(s));
    %sub.(ses{s}) = sub.(ses{s})(~ismember(sub.(ses{s}),existing_sub.(ses{s})));

    finished_ses(s) = isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s}));
    ses_run(s) = ~isempty(sub.(ses{s})) && isempty(existing_sub.(ses{s}));
    ses_add(s) = ~isempty(sub.(ses{s})) && ~isempty(existing_sub.(ses{s}));
end

assert( all(not(finished_ses)), 'All relevant subject files are moved to BIDS data structure in all sessions. Add more subject files to the data_dir.')
if any(ses_run)
    fprintf('Creating new BIDS dataset from subject files \n')
    run_mode = 'new_BIDS';
elseif any(ses_add)
    fprintf('Moving subject %s files into BIDS data structure \n',sub.(ses{s}){:})
    run_mode = 'add_sub';
end
   


%behav data xlsx file
behav_table = readtable(behav_path);
nameless_cols = check_nameless_columns(behav_table,behav_path);

%get column names from elsewhere 
clear behav_col_names
behav_col_names = readtable(behav_col_names_path).Properties.VariableNames;
assert(length(behav_col_names)==width(behav_table),'The number of column names does not match the number of columns in table');

if ~isempty(nameless_cols) && isempty(behav_col_names)
    fprintf('In %s table the following columns are nameless ',behav_path)
    fprintf('%i, ',nameless_cols)
    fprintf('Get column names for behavioural data')
elseif ~isempty(nameless_cols) && ~isempty(behav_col_names)
    fprintf('Successfully added behavioural data column names')
end

    
%% Generate BIDS structure and files

%%%%%% Use data2bids function on each subject %%%%%%%%

% for more information on data2bids function see: 
% https://github.com/fieldtrip/fieldtrip/blob/master/data2bids.m
%sub = existing_sub;


for subindx=1:numel(sub)
    for sesindx=1:numel(ses)
        
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy';
    cfg.datatype  = 'eeg';

    % specify the output directory
    cfg.bidsroot  = bids_dir;
    cfg.ses       = ses{sesindx};
    % get subject via ID 
    cfg.sub       = sub{subindx};
    sub_int       = str2num(cfg.sub);

    cfg.include_scans = false;
    
    % define datafile for current subject
    cfg.dataset   = fullfile(data_dir,bdf_file_names{subindx});

    % specify the information for the participants.tsv file
    for col = 1:total_cols
        if contains(col_names{col},participant_info_include)
            cfg.participants.(col_names{col}) = sub_info_table{via_id==sub_int,col};
        elseif contains(col_names{col},participant_info_include) && isdatetime(sub_info_table{via_id==sub_int,col}) && isnat(sub_info_table{via_id==sub_int,col})
            cfg.participants.(col_names{col}) = 'n/a';
        elseif contains(col_names{col},participant_info_include) && isdatetime(sub_info_table{via_id==sub_int,col})
            cfg.participants.(col_names{col}) = strrep(char(sub_info_table{via_id==sub_int,col}),'/','-');
        elseif contains(col_names{col},participant_info_include) && isnumeric(sub_info_table{via_id==sub_int,col}) && isnan(sub_info_table{via_id==sub_int,col})
            cfg.participants.(col_names{col}) = 'n/a';
        end
    end
    
    if strcmp(run_mode,'new_BIDS')
        cfg.dataset_description.Name = sprintf('%s EEG',task);
        cfg.dataset_description.DatasetType = 'raw';
        cfg.dataset_description.EthicsApprovals = {'The local Ethical Committee (Protocol number: H 16043682)','The Danish Data Protection Agency (IDnumber RHP-2017-003, I-suite no. 05333)'};
    end
    
    % specify some general information that will be added to the eeg.json file
    cfg.InstitutionName             = 'Amager and Hvidovre hospital';
    cfg.InstitutionalDepartmentName = 'Centre for Functional and Diagnostic Imagning and Research, Danish Research Center for Magnetic Resonance';
    cfg.InstitutionAddress          = 'Kettegard Allé 30, DK-2650 Hvidovre, Denmark';

    % provide the mnemonic and long description of the task
    cfg.TaskName        = task;
    cfg.TaskDescription = 'Subjects were repsonding to a central target arrow pointing either to the left or right flanked by non-target arrows pointing in the same direction as the target arrow (congruent) or in the opposite direction (incongruent).';
    cfg.DatasetType = 'raw';

    % EEG specific configs saved in *_eeg.json file 
    cfg.eeg.PowerLineFrequency    = 50;
    cfg.eeg.Manufacturer          = 'Biosemi';
    cfg.eeg.ManufacturersModelName = '????';
    cfg.eeg.SoftwareVersions      = 'Version ????';
    cfg.eeg.Instructions          = InstructionsC{1};
    cfg.eeg.CogPOID               = 'http://wiki.cogpo.org/index.php?title=Flanker_Task_Paradigm';
    cfg.eeg.DeviceSerialNumber    = '????';
    cfg.eeg.EEGReference          = 'Common Mode Sense (CMS) and Driven Right Leg (DRL)'; 

    swf.filter_characteristic = '????';
    swf.filter_parameter = 10;

    cfg.eeg.SoftwareFilters.Filter1       = swf;
    cfg.eeg.SoftwareFilters.Filter3       = swf;

    cfg.eeg.CapManufacturer = 'Biosemi';
    cfg.eeg.CapManufacturersModelName = '????';
    cfg.eeg.EEGPlacementScheme = 'radial';

    %%%%% EVENTS %%%%%
    cfg.events = ft_read_event(fullfile(data_dir,bdf_file_names{subindx}));
    
    for col_idx = 1:length(behav_col_names)
        col_name = behav_col_names{col_idx};
        col_values = table2cell(behav_table(behav_table.Var2==sub_int,col_idx));
        
        if all(cellfun(@isdatetime, col_values))
            col_values = convertStringsToChars(string(col_values));
        end
        
        con_incon_idx = [cfg.events.value]==65291 | [cfg.events.value]==65311 | [cfg.events.value]==65301 | [cfg.events.value]==65321;
        empty_idx = cellfun(@isempty,{cfg.events.value},'UniformOutput',1);
        condition_idx = false(1,length(empty_idx));
        condition_idx(not(empty_idx))=con_incon_idx;
        
        event_values = cell(1,length(cfg.events));
        event_values([condition_idx]) = col_values;
        event_values([not(condition_idx)]) = {'n/a'};
        [cfg.events.(col_name)] = event_values{:};
    end

    data2bids(cfg);
    
    end
end

%% Write events.json 

if strcmp(run_mode,'new_BIDS')
    %read from txt 
    eventsC = read_txt(fullfile(data_dir.via11,event_txt_file));

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
    
    cfg.TaskEventsDescription.StimulusPresentation = '????';
    
    %add value and notes to the event.json  
    cfg.TaskEventsDescription = read_events_txt(cfg.TaskEventsDescription,eventsC);
    
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
    participants_var = read_txt(fullfile(data_dir.via11,participants_var_txt));
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
    cfg.ChannelsDescription.EXG1.LongName = 'External channel 1';
    cfg.ChannelsDescription.EXG1.Description = 'Mastoid left ear';
    cfg.ChannelsDescription.EXG1.Units = 'uV';

    cfg.ChannelsDescription.EXG2.LongName = 'External channel 2';
    cfg.ChannelsDescription.EXG2.Description = 'Mastoid right ear';
    cfg.ChannelsDescription.EXG2.Units = 'uV';

    cfg.ChannelsDescription.EXG3.LongName = 'External channel 3';
    cfg.ChannelsDescription.EXG3.Description = 'Left ear lobe';
    cfg.ChannelsDescription.EXG3.Units = 'uV';

    cfg.ChannelsDescription.EXG4.LongName = 'External channel 4';
    cfg.ChannelsDescription.EXG4.Description = 'Right ear lobe';
    cfg.ChannelsDescription.EXG4.Units = 'uV';

    cfg.ChannelsDescription.EXG5.LongName = 'External channel 5';
    cfg.ChannelsDescription.EXG5.Description = 'Nose';
    cfg.ChannelsDescription.EXG5.Units = 'uV';

    cfg.ChannelsDescription.EXG6.LongName = 'External channel 6';
    cfg.ChannelsDescription.EXG6.Description = 'Below participants right eye';
    cfg.ChannelsDescription.EXG6.Units = 'uV';

    cfg.ChannelsDescription.EXG7.LongName = 'External channel 7';
    cfg.ChannelsDescription.EXG7.Description = 'Above participants right eye';
    cfg.ChannelsDescription.EXG7.Units = 'uV';

    cfg.ChannelsDescription.EXG8.LongName = 'External channel 8';
    cfg.ChannelsDescription.EXG8.Description = 'Pulse left hand';
    cfg.ChannelsDescription.EXG8.Units = 'uV';

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

file_path = mfilename('fullpath');
[ff,name,ext] = fileparts(file_path);
copyfile(strcat(file_path,'.m'), fullfile(code_dir,strcat(name,'.m')), 'f')


%also copy BIDS validator, json fix scripts and job bash script 
if strcmp(run_mode,'new_BIDS')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/BIDS_validator_EEG.py'), fullfile(code_dir,'/BIDS_validator_EEG.py'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/change_json_int_keys.py'), fullfile(code_dir,'/change_json_int_keys.py'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG_Flanker_job.sh'), fullfile(code_dir,'/EEG_Flanker_job.sh'), 'f')
end


%% NOTES

% DO NOW 
% start nyt dataset - tag højde for uregelmæssigheder i filnavne
% lav funktioner som kan genbruges - mangler nok kun electrodes - vent til der vides hvordan det skal struktureres
% dobbelt tjek creating new BIDS dataset printet 
% prøv EEG2BIDS_MMN("009","via11") og EEG2BIDS_MMN()


% TIL SIDST
% lav liste med ting der skal udfyldes i json filerne  
%    - events.json 
%    - participants.json filerne skal udfyldes med en .txt fil - husk stimuli
%    - software, matlab scripts?
%    - opgiv gentofte hospital som kontakt for mere info i forhold til participants.tsv
%    - hvilken type channels er de external?

%SPG
%placering af CSM og DRL
%electrodes, hvordan skal det struktureres? 
%rækkefølge af allerede eksisterende events fra bdf, + hvilke kolonner skal udfyldes
%     -skal de originale kolonner også med?
% conditionlabels som text eller som tal i events.tsv filen
% trigger_delay file fra MMM_events.txt, hvad er det? 
% hvor ligger selve stim lydene? -skal puttes i stim directory - stim file column i events.tsv
% readme der ligger ved /mnt/projects/VIA11/EEG/Data/###_Flanker
% hvad skal der gøres med de filer, som har 2 datasæt - hvordan har du analyseret det? 
%       - fint at de bliver fjernet med nono-keyword og antal events? 
%       - hvis tilføjes, skal der ligges en readme eller lign?
% Flanker træningsdata i /beh mappe?
% scripts brugt til at lave dataset i /code - triggers scripts?
% hvilken type channels er de external? status channel i channels.tsv???


%DCM 
%læs manual 
%læs tutorial 
%spm mailing archive, peter zeidman
%parametric emperical bayes 
%spm example scripts 
%se videoer 



%%% noter
%originale eprime filer skal ligge i sourcedata, men hvad med eprime-merge?
%Derivatives - hvad med alle de andre .mat filer? især 47conditions.mat filer
%make electrodes.tsv file based on coordinates from https://www.biosemi.com/headcap.htm
%make a coordinate system file for the electrodes 
%CHANGES file, se https://github.com/bids-standard/bids-examples/blob/master/eeg_matchingpennies/code/format_v016_to_v020.py
%ft_read_sens til electroder? 
% det vides ikke hvordan Beh4EEG.mat er lavet, men datanalysen begyndte FØR alt data var indsamlet, så det giver mening at e-merge tabellen for alle subjects ikke findes
%to events i ASSR_reg, start - slut 
%load_convert.m for MMM - vidste ikke helt hvilket der blev brugt, da analysen stadig er i gang
%sende artikel så jeg kan læse - har modtaget for ASSR, ikke udgivet for MMM
%hvad er epoching 
%trials i ASSR defineret i down_epoch_baseline_threshold.m linje 39-49, JA



%%
%load('/mnt/projects/VIA11/EEG/Anna/Flanker/Input_behavdata_Excel/Flanker_behav_Eprime_output/eegFlanker_47conditions_003.mat');
%load('/mnt/projects/VIA11/EEG/Data/Flanker_47condition/Beh4EEG.mat');
%load('/mnt/projects/VIA11/EEG/Data/Flanker_47condition/Beh4EEG_inclnew.mat') % 400 trials pr. subject
%load('/mnt/projects/VIA11/EEG/Data/Flanker_47condition/eegFlanker_47conditions_003.mat');
%load('/mnt/projects/VIA11/EEG/Data/###_Flanker/EEG_analysis/0003_data.mat')
%load('/mnt/projects/VIA11/EEG/Data/###_Flanker/EEG_analysis/0003_info.mat')
%load('/mrhome/simonyj/EEG_flanker/chanlocs.mat')

%denne fil blev lavet ved forsøget, indeholder 1800 events
%load('/mnt/projects/VIA11/EEG/Data/###_MMN/subject_009_MMN_triggers.mat')
% 
% dfile = '/mnt/projects/VIA11/EEG/Data/###_Flanker/130_ASSR_irreg+Flanker.bdf';
% events1 = ft_read_event(dfile);
% dfile = '/mnt/projects/VIA11/EEG/Data/###_Flanker/146_Flanker.bdf';
% events2 = ft_read_event(dfile);

%load('/mrhome/simonyj/EEG_BIDS/derivatives/pipeline1/sub-009/ses-via15/beh/sub-009_ses-via15_events.mat')

%events = ft_read_event('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf');
%events = ft_read_event('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf');
%data = ft_read_data('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf');
%hdr = sopen('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf','r');

%events_reg = ft_read_event('/mnt/projects/VIA11/EEG/Data/###_ASSR_reg/003_ASSR_reg.bdf');
%events_irreg = ft_read_event('/mnt/projects/VIA11/EEG/Data/###_ASSR_irreg/003_ASSR_irreg.bdf');
%events_MMM = ft_read_event('/mnt/projects/VIA11/EEG/Data/MMN_with_triggers/003_MMN_with_triggers.bdf');
%events_MMM = ft_read_event('/mnt/projects/VIA11/EEG/Data/###_MMN/003_MMN.bdf');


%loaded in onsetharvesting_eegflanker.m
%[num,txt,raw] = xlsread('/mnt/projects/VIA11/EEG/add_24062019');
%'/mnt/projects/VIA11/EEG/Anna/eegFlanker_47conditions_003.mat' files made 


%%%%%%%%%%%% EEG DATA %%%%%%%%%%
%loaded in /mnt/projects/VIA11/EEG/Scripts/Anna/Script/Flanker/Flanker_grandavg_pergroup.m
%which makes plots
% load('/mnt/projects/VIA11/EEG/Data/###_Flanker/EEG_analysis/0003_data.mat')
% load('/mnt/projects/VIA11/EEG/Data/###_Flanker/EEG_analysis/0003_info.mat')

%.bdf files and Beh4EEG_inclnew.mat are loaded in FlankerEEG_file2_preprocess.m
% to generate 0003_data.mat and 0003_info.mat 
% -- refchannels are given as EXG1 and EXG2 
% -- ft_preprocessing function used 

%hdr=sopen('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf','r');
%uV under physDim


%% Check things 
% 
% %check number of events 
% ev = {events2.value};
% con=0;
% incon=0;
% start=0;
% empty=0;
% %aa = {ev{4:end}};
% aa = ev;
% for ii = 1:length(aa)
%     if isempty(aa{ii})
%         empty = empty +1;
%     elseif aa{ii}==65291||aa{ii}==65311
%         con = con +1;
%     elseif aa{ii}==65301||aa{ii}==65321
%         incon = incon +1;
%     elseif aa{ii}==65281
%         start = start +1;
%     end 
% end
% disp(con)
% disp(incon)
% disp(start)