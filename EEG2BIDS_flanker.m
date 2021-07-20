addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')


%% Setup  

data_dir = '/home/simonyj/EEG_flanker';
bids_dir = '/home/simonyj/EEG_BIDS';

%sesssions 
ses = {'via11','via15'};

% extract file names and subject ids 
file_struct = dir(sprintf('%s/*.bdf',data_dir));
file_names = cellstr({file_struct.name});
sub = cellfun(@(x) x(1:3),file_names,'un',0);

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
    for sesindx=1:1%numel(ses)
        
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

    % define datafile for current subject
    cfg.dataset   = fullfile(data_dir,file_names{subindx});

    % specify the information for the participants.tsv file
    for col = 1:total_cols
        if contains(col_names{col},participant_info_include)
            cfg.participants.(col_names{col}) = sub_info_table{via_id==sub_int,col};

%         elseif strcmp(col_names{col},'Sex_child_v11')
%             cfg.participants.(col_names{col}) = sex_codes{sub_info_table{via_id==sub_int,col}+1};
%             participant_info_include(strcmp(participant_info_include,'Sex_child_v11'))=[];

%         elseif isdatetime(sub_info_table{via_id==sub_int,col}) && isnat(sub_info_table{via_id==sub_int,col})
%             cfg.participants.(col_names{col}) = 'n/a';
%         elseif isdatetime(sub_info_table{via_id==sub_int,col})
%             cfg.participants.(col_names{col}) = strrep(char(sub_info_table{via_id==sub_int,col}),'/','-');
%         elseif isnumeric(sub_info_table{via_id==sub_int,col}) && isnan(sub_info_table{via_id==sub_int,col})
%             cfg.participants.(col_names{col}) = 'n/a';
%         else
%             cfg.participants.(col_names{col}) = sub_info_table{via_id==sub_int,col};
        end
    end
    
    if strcmp(run_mode,'new_BIDS')
        cfg.dataset_description.Name = 'Flanker EEG';
        cfg.dataset_description.DatasetType = 'raw';
        cfg.dataset_description.EthicsApprovals = {'The local Ethical Committee (Protocol number: H 16043682)','The Danish Data Protection Agency (IDnumber RHP-2017-003, I-suite no. 05333)'};
    end
    
    % specify some general information that will be added to the eeg.json file
    cfg.InstitutionName             = 'Hvidovre hospital';
    cfg.InstitutionalDepartmentName = 'Danish Research Center for Magnetic Resonance, Centre for Functional and Diagnostic Imagning and Research';
    cfg.InstitutionAddress          = 'Kettegard Allé 30, DK-2650 Hvidovre, Denmark';

    % provide the mnemonic and long description of the task
    cfg.TaskName        = 'Flanker';
    cfg.TaskDescription = 'Subjects were repsonding to a central target arrow pointing either to the left or right flanked by non-target arrows pointing in the same direction as the target arrow (congruent) or in the opposite direction (incongruent).';
    cfg.DatasetType = 'raw';

    % EEG specific configs saved in *_eeg.json file 
    cfg.eeg.PowerLineFrequency    = 50;
    cfg.eeg.Manufacturer          = 'Biosemi';
    cfg.eeg.ManufacturersModelName = 'Biosemi super good model XX';
    cfg.eeg.SoftwareVersions      = 'Version XXX';
    cfg.eeg.Instructions          = InstructionsC{1};
    cfg.eeg.CogPOID               = 'http://wiki.cogpo.org/index.php?title=Flanker_Task_Paradigm';
    cfg.eeg.DeviceSerialNumber    = 'XXX';
    cfg.eeg.EEGReference          = 'channel average'; 

    swf.filter = 'very good filter name';
    swf.filter_parameter = '10';
    swf3.filter = 'very good second filter name';
    swf3.filter_parameter = '100';

    cfg.eeg.SoftwareFilters.Filter1       = swf;
    cfg.eeg.SoftwareFilters.Filter3       = swf3;

    cfg.eeg.CapManufacturer = 'Biosemi';
    cfg.eeg.CapManufacturersModelName = 'very nice Biosemi cap name';
    cfg.eeg.EEGPlacementScheme = 'radial';

    cfg.events = ft_read_event(fullfile(data_dir,file_names{subindx}));
    
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
    
%     RT = num2cell(repmat(5,1,length(cfg.events)));
%     [cfg.events.response_time] = RT{:};
%     
%     C    = cell(1, length(cfg.events));
%     C(:) = {'String'};
%     [cfg.events.trial_type] = C{:};

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
    filename = fullfile(bids_dir, 'task-Flanker_events.json');
    cfg.FlankerEventsDescription.Onset.Description = 'Onset of stimuli';
    cfg.FlankerEventsDescription.Onset.Units = 's';

    cfg.FlankerEventsDescription.Duration.Description = 'Duration of stimuli';
    cfg.FlankerEventsDescription.Duration.Units = 's';

    cfg.FlankerEventsDescription.Sample.Description = 'EEG Sample';
    cfg.FlankerEventsDescription.Sample.Units = 's';

    cfg.FlankerEventsDescription.Type.Description = 'Type of stimuli';
    cfg.FlankerEventsDescription.Type.Levels.STATUS = 'STATUS type';
    cfg.FlankerEventsDescription.Type.Levels.Epoch = 'Epoch type';
    cfg.FlankerEventsDescription.Type.Levels.CM_in_range = 'CM_in_range type';
    
    notes ='';
    for s = 1:length(flanker_split)
        level_key = flanker_split{s}{end};
        if ~isnan(str2double(level_key))
            cfg.FlankerEventsDescription.Value.Levels.(strcat('Int_',level_key)) = flanker_split{s}{1};
        else
            notes = strcat(notes,level_key);
        end
    end
    
    desc = sprintf('The value characterizing the event. These are the values to %s, and the description of these values includes information about %s',flanker_split{1}{end},flanker_split{1}{1});
    cfg.FlankerEventsDescription.Value.Description = desc;
    
    cfg.FlankerEventsDescription.Value.Notes = notes;
    
    cfg.FlankerEventsDescription.StimulusPresentation = 'Stimuli presentation software';

    fn = fieldnames(cfg.FlankerEventsDescription);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    FlankerEventsDescription_settings = keepfields(cfg.FlankerEventsDescription, fn);
    ft_write_json(filename, FlankerEventsDescription_settings);
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
    filename = fullfile(cfg.bidsroot, 'task-Flanker_channels.json');
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


%% Write electrode.tsv file 

if strcmp(run_mode,'new_BIDS')
    elec_tab = readtable('/home/simonyj/EEG_flanker/Extracted_electrode_positions.xlsx');
    %writetable(elec_tab,fullfile(bids_dir,'task-Flanker_electrodes.tsv'),'Delimiter','\t')
end

%% Write coordsystem.json

if strcmp(run_mode,'new_BIDS')
    filename = fullfile(cfg.bidsroot, 'task-Flanker_coordsystem.json');

    cfg.Coordsystem.EEGCoordinateSystem = '';
    cfg.Coordsystem.EEGCoordinateUnits = 'Pulse left hand';
    cfg.Coordsystem.EEGCoordinateSystemDescription = '????';

    fn = fieldnames(cfg.Coordsystem);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    Coordsystem_settings = keepfields(cfg.Coordsystem, fn);
    ft_write_json(filename, Coordsystem_settings);
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
    copyfile(fullfile(data_dir,'/EEG2BIDS/BIDS_validator_EEG.py'), fullfile(code_dir,'/BIDS_validator_EEG.py'), 'f')
    copyfile(fullfile(data_dir,'/EEG2BIDS/change_json_int_keys.py'), fullfile(code_dir,'/change_json_int_keys.py'), 'f')
    copyfile(fullfile(data_dir,'/EEG2BIDS/EEG_Flanker_job.sh'), fullfile(code_dir,'/EEG_Flanker_job.sh'), 'f')
end

%% Move eprime data into /sourcedata directory

sourcedata_dir = fullfile(bids_dir,'/sourcedata');
if not(isfolder(sourcedata_dir))
    mkdir(sourcedata_dir)
end

for subindx=1:numel(sub)
    for sesindx=1:numel(ses)
        
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy';
    cfg.datatype  = 'events';
    cfg.non_raw_data = true;
    
    % specify the output directory
    cfg.bidsroot  = sourcedata_dir;
    cfg.ses       = ses{sesindx};
    % get subject via ID 
    cfg.sub       = sub{subindx};
    sub_int       = str2num(cfg.sub);

    % define datafile for current subject
    cfg.dataset   = fullfile(data_dir,sprintf('flanker_kids_eegBackup_new-%s-1.edat2',cfg.sub));
    
    data2bids(cfg)
    
    end
end

% remove files not needed in the sourcedata directory
sfile_names = cellstr({ dir(fullfile(sourcedata_dir, '**/*_scans.tsv')).name });
sfile_dirs = cellstr({ dir(fullfile(sourcedata_dir, '**/*_scans.tsv')).folder });
sfiles2del = strcat(sfile_dirs,'/',sfile_names);
sfiles2del{end+1} = fullfile(sourcedata_dir, '/participants.tsv');
sfiles2del{end+1} = fullfile(sourcedata_dir, '/dataset_description.json');

for f = 1:length(sfiles2del)
    delete(sfiles2del{f})
end

%write a readme about the e-prime data 
fileID = fopen(fullfile(sourcedata_dir,'README.txt'),'w');
fprintf(fileID,'E-prime behavioural sourcedata aqcuired for the flanker task');
fclose(fileID);


%% Make derivative directory 

derivative_dir = fullfile(bids_dir,'/derivatives/pipeline1');
deriv_code_dir = fullfile(derivative_dir,'/code');

if not(isfolder(deriv_code_dir))
    mkdir(deriv_code_dir)
end

for subindx=1:numel(sub)
    for sesindx=1:1%numel(ses)
        
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy';
    cfg.datatype  = 'eeg_deriv';
    cfg.non_raw_data = true;
    
    % specify the output directory
    cfg.bidsroot  = derivative_dir;
    cfg.ses       = ses{sesindx};
    % get subject via ID 
    cfg.sub       = sub{subindx};
    sub_int       = str2num(cfg.sub);

    % define datafile for current subject
    cfg.dataset   = fullfile(data_dir,sprintf('/0%s_data.mat',cfg.sub));
    data2bids(cfg)

    filename = fullfile(derivative_dir, sprintf('/sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-Flanker_%s.json',cfg.sub,cfg.ses,cfg.sub,cfg.ses,cfg.datatype));
    cfg.DerivativeDescriptionEEG.Description = 'Preprocessed using the fieldtrip toolbox, where only correct congruent and incongruent trials were used. Assumed to be produced by FlankerEEG_file2_preprocess.m being run for each subject.';
    cfg.DerivativeDescriptionEEG.Sources = {'../../Beh4EEG_inclnew.mat',sprintf('../../sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-Flanker_eeg.bdf',cfg.sub,cfg.ses,cfg.sub,cfg.ses)};
    fn = fieldnames(cfg.DerivativeDescriptionEEG);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    DerivativeDescriptionEEG_settings = keepfields(cfg.DerivativeDescriptionEEG, fn);
    ft_write_json(filename, DerivativeDescriptionEEG_settings);

    
    cfg.dataset   = fullfile(data_dir,sprintf('/0%s_info.mat',cfg.sub));
    cfg.datatype  = 'beh_info';
    data2bids(cfg)
    
    filename = fullfile(derivative_dir, sprintf('/sub-%s/ses-%s/beh/sub-%s_ses-%s_task-Flanker_%s.json',cfg.sub,cfg.ses,cfg.sub,cfg.ses,cfg.datatype));
    cfg.DerivativeDescriptionBehav.Description = 'Preprocessed using the fieldtrip toolbox, where only correct congruent and incongruent trials were used. Assumed to be produced by FlankerEEG_file2_preprocess.m being run for each subject.';
    cfg.DerivativeDescriptionBehav.Sources = {'../../Beh4EEG_inclnew.mat',sprintf('../../sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-Flanker_eeg.bdf',cfg.sub,cfg.ses,cfg.sub,cfg.ses)};
    fn = fieldnames(cfg.DerivativeDescriptionBehav);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    DerivativeDescriptionBehav_settings = keepfields(cfg.DerivativeDescriptionBehav, fn);
    ft_write_json(filename, DerivativeDescriptionBehav_settings);
    
    end
end

%% Make derivative dataset_description.json file 

filename = fullfile(derivative_dir, 'dataset_description.json');

cfg.DerivativeDescription.Name = 'preprocessed EEG and behavioural data';
cfg.DerivativeDescription.BIDSVersion = '1.2';
cfg.DerivativeDescription.DatasetType = 'derivative';

cfg.DerivativeDescription.GeneratedBy.Name = 'pipeline1';
cfg.DerivativeDescription.GeneratedBy.Version = '1.0';
cfg.DerivativeDescription.GeneratedBy.Description = 'Preprocessed using the fieldtrip toolbox, where only correct congruent and incongruent trials were used. Assumed to be produced by FlankerEEG_file2_preprocess.m being run for each subject.';
cfg.DerivativeDescription.GeneratedBy.CodeURL = 'Maybe make github repo?';

fn = fieldnames(cfg.DerivativeDescription);
fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
DerivativeDescription_settings = keepfields(cfg.DerivativeDescription, fn);
ft_write_json(filename, DerivativeDescription_settings);


% Move scripts used to produce derivative into code/ directory
copyfile(fullfile(data_dir,'/FlankerEEG_file2_preprocess.m'), fullfile(deriv_code_dir,'/FlankerEEG_file2_preprocess.m'), 'f')

%move behavioural data .mat file into root dir 
copyfile(fullfile(data_dir,'/Beh4EEG_inclnew.mat'), fullfile(bids_dir,'/Beh4EEG_inclnew.mat'), 'f')


%%

% lav liste med ting der skal udfyldes i json filerne  
%    - events.json og
%    - participants.json filerne skal udfyldes med en .txt fil - husk stimuli
%    - software, matlab scripts?
%    - opgiv gentofte hospital som kontakt for mere info i forhold til participants.tsv
% sæt derivatives på pause - der er for mange ting vi ikke ved 
% det vides ikke hvordan Beh4EEG.mat er lavet, men datanalysen begyndte FØR alt data var indsamlet, så det giver mening at e-merge tabellen for alle subjects ikke findes
% del scriptet op i raw, source og derivative? evt en inddeling så man bare skal køre et script efter forsøg
% lav electrode-filer både for den Melissa har givet dig, samt en du laver fra biosemi - kan man input noget i en excel fil med macros? 
% start nyt dataset - tag højde for uregelmæssigheder i filnavne
% CSM reference channel for EEG 
% prøv evt. andre BIDS validators for at se om de kigger i json filer efter fejl

%RÆKKEFØLGE
% -del script op i raw, source og derivative 
% -start på nyt dataset for at lære hvordan script skal generaliseres
        % -skal man kunne vælge: med eller uden behav data?

%to events i ASSR_reg 
%lav 1800 events i den ene 

%%% todo 
%originale eprime filer skal ligge i sourcedata, men hvad med eprime-merge?
%skal alt hvad der er i eprime-merge med i events.tsv? - PAS PÅ; der er mere end 400 events i events.tsv
%Derivatives - hvad med alle de andre .mat filer? især 47conditions.mat filer
%make electrodes.tsv file based on coordinates from https://www.biosemi.com/headcap.htm
%make a coordinate system file for the electrodes 
%CHANGES file, se https://github.com/bids-standard/bids-examples/blob/master/eeg_matchingpennies/code/format_v016_to_v020.py
%ft_read_sens til electroder? 


%%
%load('/mnt/projects/VIA11/EEG/Anna/Flanker/Input_behavdata_Excel/Flanker_behav_Eprime_output/eegFlanker_47conditions_003.mat');
%load('/mnt/projects/VIA11/EEG/Data/Flanker_47condition/Beh4EEG.mat');
%load('/mnt/projects/VIA11/EEG/Data/Flanker_47condition/Beh4EEG_inclnew.mat') % 400 trials pr. subject
%load('/mnt/projects/VIA11/EEG/Data/Flanker_47condition/eegFlanker_47conditions_003.mat');
%load('/mnt/projects/VIA11/EEG/Data/###_Flanker/EEG_analysis/0003_data.mat')
%load('/mnt/projects/VIA11/EEG/Data/###_Flanker/EEG_analysis/0003_info.mat')
%load('/mrhome/simonyj/EEG_flanker/chanlocs.mat')

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

  