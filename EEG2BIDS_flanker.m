addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')


%% Setup  

data_dir = '/home/simonyj/EEG_flanker';
bids_dir = '/home/simonyj/EEG_BIDS_flanker';
EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';

if not(isfolder(bids_dir))
    mkdir(bids_dir)
end

task = 'Flanker';

%sesssions 
ses = {'via11','via15'};

% extract file names and subject ids 
file_struct = dir(sprintf('%s/*.bdf',data_dir));
bdf_file_names = cellstr({file_struct.name});
sub = cellfun(@(x) x(1:3),bdf_file_names,'un',0);

%find already existing subs by subject folders
sub_dirs = dir(sprintf('%s/sub-*',bids_dir));
file_dirs = cellstr({sub_dirs.name});
existing_sub = cellfun(@(x) x(end-2:end),file_dirs,'un',0);

%check that the subjects with existing sub folders have the needed files 
files_checked = {'eeg.bdf','eeg.json','events.tsv','channels.tsv'};
for f = 1:length(files_checked)
    sub_dirs = dir(sprintf('%s/sub-*/ses-*/eeg/*_%s',bids_dir,files_checked{f}));
    file_dirs = {sub_dirs.name};
    subs_with_file = cellfun(@(x) x(5:7),file_dirs,'un',0);
    if any(~ismember(existing_sub,subs_with_file))
        sub2redo = existing_sub{~ismember(existing_sub,subs_with_file)};
        existing_sub(strcmp(existing_sub,sub2redo))=[];
        fprintf('Subject %s have missing BIDS files \n',sub2redo)
    end
end
sub = sub(~ismember(sub,existing_sub));

%sub = {sub{1:2}};

if isempty(sub) && ~isempty(existing_sub)
    assert(~isempty(sub),'All relevant subject files are moved to BIDS data structure. Add more subject files to the data_dir.')
elseif ~isempty(sub) && isempty(existing_sub)
    fprintf('Creating new BIDS dataset from subject files \n')
    run_mode = 'new_BIDS';
else
    fprintf('Moving subject %s files into BIDS data structure \n',sub{:})
    run_mode = 'add_sub';
end


% parse a subject info table from databse for participant information
sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
sub_info_table = readtable(sub_info_table_path);
total_cols = width(sub_info_table);
col_names = sub_info_table.Properties.VariableNames;
via_id = sub_info_table.famlbnr;
sub_info_table = table2cell(sub_info_table);

%only include these participant info variables
participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

%behav data xlsx file
behav_path = '/mnt/projects/VIA11/EEG/Anna/Flanker/Input_behavdata_Excel/Flankerbehav090119.xls';
behav_table = readtable(behav_path);

%get coloumn names from elsewhere 
behav_col_names_path = '/mnt/projects/VIA11/EEG/Data/Flanker_47condition/EEG_Flanker.txt';
behav_col_names = readtable(behav_col_names_path).Properties.VariableNames;

%read instructions 
fid = fopen(fullfile(data_dir,'Flanker_instructions.txt'), 'r');
if fid == -1
  error('Cannot open file fpr reading: %s', FileName);
end
txtC = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
InstructionsC  = txtC{1};
fclose(fid);

    
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
            
%         elseif strcmp(col_names{col},'Sex_child_v11')
%             cfg.participants.(col_names{col}) = sex_codes{sub_info_table{via_id==sub_int,col}+1};
%             participant_info_include(strcmp(participant_info_include,'Sex_child_v11'))=[];
%         else
%             cfg.participants.(col_names{col}) = sub_info_table{via_id==sub_int,col};
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

    swf.filter = '????';
    swf.filter_parameter = '10';
    swf3.filter = '????';
    swf3.filter_parameter = '100';

    cfg.eeg.SoftwareFilters.Filter1       = swf;
    cfg.eeg.SoftwareFilters.Filter3       = swf3;

    cfg.eeg.CapManufacturer = 'Biosemi';
    cfg.eeg.CapManufacturersModelName = '????';
    cfg.eeg.EEGPlacementScheme = 'radial';

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

%read from txt 
fid = fopen(fullfile(data_dir,'Flanker_events.txt'), 'r');
if fid == -1
  error('Cannot open file fpr reading: %s', FileName);
end
txtC = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
flanker_events  = txtC{1};
fclose(fid);

flanker_split = cellfun(@(x) split(x,char(9)),flanker_events,'UniformOutput',0);

if strcmp(run_mode,'new_BIDS')
    filename = fullfile(bids_dir, sprintf('task-%s_events.json',task));
    cfg.TaskEventsDescription.onset.Description = 'Onset of stimuli';
    cfg.TaskEventsDescription.onset.Units = 's';

    cfg.TaskEventsDescription.duration.Description = 'Duration of stimuli';
    cfg.TaskEventsDescription.duration.Units = 's';

    cfg.TaskEventsDescription.sample.Description = 'EEG Sample';
    cfg.TaskEventsDescription.sample.Units = 's';

    cfg.TaskEventsDescription.type.Description = 'Type of stimuli';
    cfg.TaskEventsDescription.type.Levels.STATUS = 'STATUS type';
    cfg.TaskEventsDescription.type.Levels.Epoch = 'Epoch type';
    cfg.TaskEventsDescription.type.Levels.CM_in_range = 'CM_in_range type';
    
    notes ='';
    for s = 2:length(flanker_split)
        level_key = flanker_split{s}{end};
        if ~isnan(str2double(level_key))
            cfg.FlankerEventsDescription.value.Levels.(strcat('Int_',level_key)) = flanker_split{s}{1};
        else
            notes = strcat(notes,level_key);
        end
    end
    
    desc = sprintf('The value characterizing the event. These are the values to %s, and the description of these values includes information about %s',flanker_split{1}{end},flanker_split{1}{1});
    cfg.TaskEventsDescription.value.Description = desc;
    
    cfg.TaskEventsDescription.Notes = notes;
    
    cfg.TaskEventsDescription.StimulusPresentation = '????';

    fn = fieldnames(cfg.TaskEventsDescription);
    TaskEventsDescription_settings = keepfields(cfg.FlankerEventsDescription, fn);
    ft_write_json(filename, TaskEventsDescription_settings);
end



%% Write participants.json from .txt file

if strcmp(run_mode,'new_BIDS')
    
    %read from txt 
    fid = fopen(fullfile(data_dir,'participants_variables.txt'), 'r');
    if fid == -1
      error('Cannot open file fpr reading: %s', FileName);
    end
    txtC = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
    participants_var  = txtC{1};
    fclose(fid);

    info_split = cellfun(@(x) split(x,':'),participants_var,'UniformOutput',0);
    valid_keys = {'LongName','Description','Levels','Units'};
    name_indices = find(contains(participants_var,'Name')==1);
    
    var_names = {};
    for n = 1:length(name_indices)
        ii = name_indices(n);
        if strcmp(info_split{ii}{1},'Name') && ismember(strtrim(info_split{ii}{2}),participant_info_include)

            for jj = 1:length(valid_keys)

                if ismember(info_split{ii+jj}{1},valid_keys) && strcmp(info_split{ii+jj}{1},'Levels')                
                    levelsC = strtrim(split(join(info_split{ii+jj}(2:end)),','));
                    split_idx = cell2mat(cellfun(@(x) x(1),strfind(levelsC,' '),'UniformOutput',0));

                    for kk = 1:length(levelsC)
                        level_key = strtrim(levelsC{kk}(1:split_idx(kk)));
                        level_value = strtrim(levelsC{kk}(split_idx(kk):end));
                        if isnan(str2double(level_key))
                            cfg.ParticipantsDescription.(strtrim(info_split{ii}{2})).(strtrim(info_split{ii+jj}{1})).(level_key) = level_value;
                        else
                            cfg.ParticipantsDescription.(strtrim(info_split{ii}{2})).(strtrim(info_split{ii+jj}{1})).(strcat('Int_',level_key)) = level_value;                        
                        end
                    end

                elseif ismember(info_split{ii+jj}{1},valid_keys)
                    cfg.ParticipantsDescription.(strtrim(info_split{ii}{2})).(strtrim(info_split{ii+jj}{1})) = strtrim(info_split{ii+jj}{2});
                end
                
                if (ii+jj==length(info_split)) 
                    break;
                end
            end

            var_names{end+1}=strtrim(info_split{ii}{2});
        end

    end
    non_described_var_idx = ismember(participant_info_include,var_names);
    assert(any(non_described_var_idx),sprintf('%s variable is not described in participant info description .txt file',participant_info_include{non_described_var_idx}))

    %write the file 
    filename = fullfile(bids_dir, 'participants.json');
    
    fn = fieldnames(cfg.ParticipantsDescription);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
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
% prøv evt. andre BIDS validators for at se om de kigger i json filer efter fejl/mangler
% opdater job scriptet 
% tage højde for session med nyt data_dir
% lav funktioner som kan genbruges 


% TIL SIDST
% lav liste med ting der skal udfyldes i json filerne  
%    - events.json 
%    - participants.json filerne skal udfyldes med en .txt fil - husk stimuli
%    - software, matlab scripts?
%    - opgiv gentofte hospital som kontakt for mere info i forhold til participants.tsv


%SPG
%placering af CSM og DRL
%electrodes, hvordan skal det struktureres? 
%rækkefølge af allerede eksisterende events fra bdf, + hvilke kolonner skal udfyldes
%     -skal de originale kolonner også med?
% conditionlabels som text eller som tal i events.tsv filen
% trigger_delay file fra MMM_events.txt, hvad er det? 
% hvor ligger selve stim lydene? -skal puttes i stim directory


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

%% Testing things 

% cfg = [];
% cfg.dataset             = ['/mnt/projects/VIA11/EEG/Data/###_Flanker/009_Flanker.bdf'];
% cfg.trialdef.prestim    = 0.5;
% cfg.trialdef.poststim   = 1.5;
% cfg.trialdef.eventtype  = 'STATUS';
% cfg.trialdef.eventvalue = {65291, 65311};
% cfg_con                 = ft_definetrial(cfg);
% 
% cfg.trialdef.eventvalue = {65301, 65321};
% cfg_incon               = ft_definetrial(cfg);



%check number of events 
% events = ft_read_event('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf');
% ev = {events.value};
% con=0;
% incon=0;
% aa = {ev{4:end}};
% for ii = 1:length(aa)
%     if aa{ii}==65291||aa{ii}==65311
%         con = 0con +1;
%     elseif aa{ii}==65301||aa{ii}==65321
%         incon = incon +1;
%     end 
% end

% event = cfg.events;
% 
%     onset        = (([event.sample]-1)/4096)';   % in seconds
%     duration     = ([event.duration]/4096)';     % in seconds
%     sample       = ([event.sample])';              % in samples, the first sample of the file is 1
%     type         = {event.type}';
%     value        = {event.value}';
%     
%   if all(cellfun(@isnumeric, type))
%     % this can be an array of strings or values
%     type = cell2mat(type);
%   end
%   if all(cellfun(@isnumeric, value))
%     % this can be an array of strings or values
%     value = cell2mat(value);
%   end
%   
%   fn = fieldnames(event);
%   additional_measures = {};
%   for ii = 1:length(fn)-5
%     col = {event.(fn{ii+5})};
%     if all(cellfun(@isnumeric, col))
%     %    this can be an array of strings or values
%         additional_measures{end+1} = cell2mat(col);
%     else
%         additional_measures{end+1} = col;
%     end
%   end
% 
%   if exist('sample', 'var')
%     tab = table(onset, sample, type, [value;100;100]);
%     for ii = 1:length(fn)-5
%         tab = [ table(additional_measures{ii}', 'VariableNames', {fn{ii+5}})  tab];
%     end
%   end
  
%     cfg.events = ft_read_event(fullfile(data_dir,file_names{subindx}));
% 
% 
%     for col_idx = 1:length(behav_col_names)
%         col_name = behav_col_names{col_idx};
%         col_values = table2cell(behav_table(behav_table.Var2==sub_int,col_idx));
%         
%         if all(cellfun(@isdatetime, col_values))
%             col_values = convertStringsToChars(string(col_values));
%         end
%         
%         con_incon_idx = [cfg.events.value]==65291 | [cfg.events.value]==65311 | [cfg.events.value]==65301 | [cfg.events.value]==65321;
%         event_values = cell(1,length(cfg.events));
%         event_values([con_incon_idx]) = col_values;
%         event_values([not(con_incon_idx)]) = {'n/a'};
%         [cfg.events.(col_name)] = event_values{:};
%     end



%TAB = readtable('/mrhome/simonyj/EEG_BIDS/sub-009/ses-via11/eeg/sub-009_ses-via11_task-Flanker_events.tsv','FileType','text');


% 
% 
% ft_tab = ft_read_tsv('/mrhome/simonyj/EEG_BIDS/sub-009/ses-via11/eeg/sub-009_ses-via11_task-Flanker_events.tsv');
% ft_tab2 = output_compatible(ft_tab);
% 
% 
% function val = output_compatible(val)
% if istable(val)
%   fn = val.Properties.VariableNames;
%   for i=1:numel(fn)
%     val.(fn{i}) = output_compatible(val.(fn{i}));
%   end
% elseif iscell(val)
%   % use recursion to make all elements compatible
%   val = cellfun(@output_compatible, val, 'UniformOutput', false);
% elseif isnumeric(val) && numel(val)>1 && any(isnan(val))
%   % convert and use recursion to make all elements compatible
%   val = num2cell(val);
%   val = cellfun(@output_compatible, val, 'UniformOutput', false);
% else
%   % write [] as 'n/a'
%   % write nan as 'n/a'
%   % write boolean as 'True' or 'False'
%   if isempty(val)
%     val = 'n/a';
%   elseif isnan(val)
%     val = 'n/a';
%   elseif islogical(val)
%     if val
%       val = 'True';
%     else
%       val = 'False';
%     end
%   end
% end
% end

%%%% CHANGE STRING NUMBERS TO NUMERIC VALUES IN CELL STRINGS OF TABLE
%        fn = existing.Properties.VariableNames;
%       for ii=1:numel(fn)
%           a = existing.(fn{ii});
%           if ~isnumeric(a)
%               mask = cellfun(@(x) ~isnan(str2double(x)),a);
%               aa = a;
%               aa(mask) = cellfun(@str2num, a(mask,:), 'un', 0);
%               existing.(fn{ii}) = aa;
%           end
%       end

  