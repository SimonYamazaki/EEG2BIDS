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


%% NOTES

%SPG
% hvor meget skal i task instructions fra word filen? -bare selv tilføj noget så det giver mening - skal alt det i starten med?
% skal det så være run eller task? 
% hvilken type channels er de external? status channel i channels.tsv - den sidste???
% Flanker træningsdata i /beh mappe? - det må godt komme med - det er sourcedata!?
% convertering til EDF?

% COMMENTS
% kan der ligger mere end én .bdf fil i /eeg mappen? - ja, skal være adskilt med task eller run 
% kan man ligge flere tasks sammen i et bids_dir? - ja, fx. ds002 i bids-examples


% DO NOW 
% samle warnings et bestemt sted i .out filen, så man nemmere kan se det for hele datasettet i stedet for at skulle lede det hele igennem?
% make it optional to parse data_dir to EEG2BIDS.sh
% lav liste med ting der skal udfyldes - aka alle ???? - send dem løbende som noget der skal udfyldes 
% make comments in scripts
% lav en EEG2BIDS_template.m - når EEG2BIDS_MMN er færdig med ændringer
%       - fyld behav data i med column name check 
%       - lav electrodes filer
%lav flanker og ASSR_irreg scripts, når bdf file split er lavet
%lav data_file til et struct så filerne kan hedde noget anderledes i hver
%session - tage højde for dette i find_sub_ids.m


% ÆNDRINGER
% hvad skal der gøres med de filer, som har 2 datasæt - hvordan har du analyseret det? 
%       - hvis tilføjes, skal der ligges en readme eller lign? - kunne man godt
%       - split filerne op hvis muligt med en funktion - kan gøres med actiview


% hvor ligger selve stim lydene? stim file column i events.tsv - melissa finder dem 
% scripts brugt til at lave dataset i /code - triggers scripts? - melissa finder den


% LISTEN
% lav liste med ting der skal udfyldes i json filerne  
%    - events.json 
%    - participants.json filerne skal udfyldes med en .txt fil - husk stimuli
%    - software, matlab scripts?
%    - opgiv gentofte hospital som kontakt for mere info i forhold til participants.tsv
%    - hvilken type channels er de external?



%%% noter
% originale eprime filer skal ligge i sourcedata, men hvad med eprime-merge?
% Derivatives - hvad med alle de andre .mat filer? især 47conditions.mat filer
% CHANGES file, se https://github.com/bids-standard/bids-examples/blob/master/eeg_matchingpennies/code/format_v016_to_v020.py
% det vides ikke hvordan Beh4EEG.mat er lavet, men datanalysen begyndte FØR alt data var indsamlet, så det giver mening at e-merge tabellen for alle subjects ikke findes
% to events i ASSR_reg, start - slut 
% load_convert.m for MMM - vidste ikke helt hvilket der blev brugt, da analysen stadig er i gang
% sende artikel så jeg kan læse - har modtaget for ASSR, ikke udgivet for MMM 
% trials i ASSR defineret i down_epoch_baseline_threshold.m linje 39-49, JA
% channels.mat i ASSR_reg data mappen? - er bare channel labels A1, A2 ...
% placering af CSM og DRL - ligegyldigt 
% electrodes, hvordan skal det struktureres? - fjern dem 
% rækkefølge af allerede eksisterende events fra bdf, + hvilke kolonner skal udfyldes
%     -skal de originale kolonner også med? - originale skal med, og de skal ligge øverst
% conditionlabels som text eller som tal i events.tsv filen - text er fint 
% tilføjede events være "STATUS"? - JA
% trigger_delay file fra MMM_events.txt, hvad er det? - skal ikke med, den info ligger i de 37 mns 
% readme der ligger ved /mnt/projects/VIA11/EEG/Data/###_Flanker - skal ikke med
% hvad skal der gøres med de filer, som har 2 datasæt - hvordan har du analyseret det? 
%       - fint at de bliver fjernet med nono-keyword og antal events? - JA
%       - hvis tilføjes, skal der ligges en readme eller lign? - kunen man godt
%       - split filerne op hvis muligt med en funktion
% Flanker træningsdata i /beh mappe? - det må godt komme med
% skal trl2(1,3)=-fs; med i ASSR events - NEJ
% skal både duration og start stop være med i ASSR events + MMN  - kun duration og onset. Onset for stimuli ikke epoch
% har ASSR_reg og ASSR_irreg samme events? - JA 
% uV står under physDim i bdf header

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




%% Loading the BDF file 

% addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')
% addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t250_ArtifactPreProcessingQualityControl/')
% 
% %regular file 
% HDR1=sopen('/mnt/projects/VIA11/EEG/Data/###_Flanker/003_Flanker.bdf','r');
% [S1,HDR1] = sread(HDR1);
% HDR1 = sclose(HDR1);
% 
% %get onset time for a merged file
% filename = '/mnt/projects/VIA11/EEG/Data/###_Flanker/130_ASSR_irreg+Flanker.bdf';
% HDR = sopen(merged_files{ii},'r');
% [S,HDR] = sread(HDR);
% HDR = sclose(HDR);
% file_onset_sample = HDR.EVENT.POS(HDR.EVENT.TYP == 65280);
% file_onset_time = file_onset_sample/HDR.fn.SampleRate;


%multiple files
% merged_files = {'/mnt/projects/VIA11/EEG/Data/###_Flanker/130_ASSR_irreg+Flanker.bdf',...
%     '/mnt/projects/VIA11/EEG/Data/###_ASSR_reg/449_ASSR_reg_and_irreg_sorry.bdf'};
% 
% for ii = 1:length(merged_files)
%     fn = (strcat('file',num2str(ii)));
%     HDR.(fn) = sopen(merged_files{ii},'r');
%     [S.(fn),HDR.(fn)] = sread(HDR.(fn));
%     HDR.(fn) = sclose(HDR.(fn));
%     
%     file_onset_sample.(fn) = HDR.(fn).EVENT.POS(HDR.(fn).EVENT.TYP == 65280);
%     file_onset_time.(fn) = file_onset_sample/HDR.(fn).SampleRate;
% end


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

%% Testing what comes out of spm_eeg_definetrial(S)
% addpath('/mnt/projects/VIA11/EEG/EEG_tools/spm12.7771')
% spm('defaults','eeg');
% filename = '/home/simonyj/EEG_ASSR_reg/mont_dnotch_fLfH_spmeeg_009_ASSR_reg.mat';
% eventvalue = 1;
% 
% %Epoching
% %cd('/mnt/projects/VIA11/EEG/Analysis_ASSR/Pre_processed');
% S = [];
% S.D = filename;
% S.timewin                 = [-1000 2000];
% S.trialdef.conditionlabel = 'click';
% S.trialdef.eventtype      = 'STATUS';
% S.trialdef.eventvalue     = eventvalue;
% S.traildef.trlshift       = 0;
% S.reviewtrials            = 0;
% S.save                    = 0;
% [trl, conditionlabels, S] = spm_eeg_definetrial(S);
% 
% trl

