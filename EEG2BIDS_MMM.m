addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/utilities/')
addpath('/mrhome/simonyj/biosig-code/biosig4matlab/t200_FileAccess/')


%% Setup  

data_dir = '/home/simonyj/EEG_MMN';
%data_dir.via15 = '/home/simonyj/EEG_MMN';
EEG2BIDS_tool_dir = '/home/simonyj/EEG2BIDS';
bids_dir = '/home/simonyj/EEG_BIDS_MMN';

if not(isfolder(bids_dir))
    mkdir(bids_dir)
end

task = 'MMN';
nono_keywords_in_filename = {'Flanker','ASSR'};

%sesssions 
ses = {'via11','via15'};


% parse a subject info table from databse for participant information
sub_info_table_path = '/mnt/projects/VIA11/database/VIA11_allkey_160621.csv';
sub_info_table = readtable(sub_info_table_path);
total_cols = width(sub_info_table);
col_names = sub_info_table.Properties.VariableNames;
via_id = sub_info_table.famlbnr;
sub_info_table = table2cell(sub_info_table);


% extract file names and subject ids 
file_struct = dir(sprintf('%s/*.bdf',data_dir));
bdf_file_names = cellstr({file_struct.name});
sub = cell(1,length(bdf_file_names));
sub_split = cellfun(@(x) split(x,{'subject','sub','_','-','.'}),bdf_file_names,'UniformOutput',0);
for ii = 1:length(bdf_file_names)
    if ismember(task,sub_split{ii}) && ~any(ismember(nono_keywords_in_filename,sub_split{ii})) 
        numeric_idx = cell2mat(cellfun(@(x) ~isnan(str2double(x)),sub_split{ii},'UniformOutput',0));
        db_idx = ismember(sub_split{ii},cellstr(num2str(via_id,'%03d')));
        sub{ii} = sub_split{ii}{and(numeric_idx,db_idx)};
    end
end

%%
%check if subject has accompanying files
xfile_struct = dir(sprintf('%s/*_triggers.mat',data_dir));
xfile_names = cellstr({xfile_struct.name});
sub_triggers = cell(1,length(xfile_names));
sub_triggers_split = cellfun(@(x) split(x,{'sub','_','-'}),xfile_names,'UniformOutput',0);
for ii = 1:length(xfile_names)
    numeric_idx = cell2mat(cellfun(@(x) ~isnan(str2double(x)),sub_triggers_split{ii},'UniformOutput',0));
    db_idx = ismember(sub_split{ii},cellstr(num2str(via_id,'%03d')));
    sub_triggers{ii} = sub_triggers_split{ii}{and(numeric_idx,db_idx)};
end

if isequal(sub,sub_triggers)
    fprintf('\nAll subjects with .bdf files also have trigger files \n')
elseif length(sub)==length(sub_triggers) && ~isequal(sub,sub_triggers)
    fprintf('Did not find match between subjects with .bdf files and subjects with trigger .mat files. Check if subject ID search pattern is correct \n')
elseif length(sub)>length(sub_triggers)
    fprintf('Subject %s has .bdf file but are missing a trigger file \n',sub{~ismember(sub,sub_triggers)} )
elseif length(sub)<length(sub_triggers)
    fprintf('Subject %s has trigger file but are missing .bdf file \n',sub_triggers{~ismember(sub_triggers,sub)} )
end


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


if isempty(sub) && ~isempty(existing_sub)
    assert(~isempty(sub),'All relevant subject files are moved to BIDS data structure. Add more subject files to the data_dir.')
elseif ~isempty(sub) && isempty(existing_sub)
    fprintf('Creating new BIDS dataset from subject files \n')
    run_mode = 'new_BIDS';
else
    fprintf('Moving subject %s files into BIDS data structure \n',sub{:})
    run_mode = 'add_sub';
end


%only include these participant info variables
participant_info_include = {'MRI_age_v11', 'Sex_child_v11','HighRiskStatus_v11'};

%read instructions 
fid = fopen(fullfile(data_dir,'MMN_instructions.txt'), 'r');
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
    cfg.TaskDescription = '????';
    cfg.DatasetType = 'raw';

    % EEG specific configs saved in *_eeg.json file 
    cfg.eeg.PowerLineFrequency    = 50;
    cfg.eeg.Manufacturer          = 'Biosemi';
    cfg.eeg.ManufacturersModelName = '????';
    cfg.eeg.SoftwareVersions      = '????';
    cfg.eeg.Instructions          = InstructionsC{1};
    cfg.eeg.CogPOID               = '????';
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

    %%%%%%%%
    event_struct = ft_read_event(fullfile(data_dir,bdf_file_names{subindx}));
    
    %check that the .bdf file only contains the expected amount of events
    if sum([event_struct.value]==65281)~=1
        fprintf('Subject %s has more trigger start events than expected. Check whether the .bdf file includes tasks other than %s.',cfg.sub,task)
        %fprintf('WARNING: Not including subject %s in the bids structure as the .bdf file includes more events than expected',cfg.sub,task)
    end
    
    fs = ft_read_header(fullfile(data_dir,bdf_file_names{subindx})).Fs; %4096
    delay = 37;
    
    load(sprintf('%s/subject_%s_MMN_triggers.mat',data_dir,cfg.sub));

    %Epoching
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
    
    trig=round(start_samples/(44100/4096));

    for i = 2:length(trig)
        S.trl(i,1)=S.trl(1,1)+trig(i);

        if mmn_codes(i)==1
            S.conditionlabels{i,:}= 'std';
        elseif mmn_codes(i) ==2
            S.conditionlabels{i,:}= 'dev1';
        elseif mmn_codes(i) ==3
            S.conditionlabels{i,:}='dev2';
        elseif mmn_codes(i) ==4
            S.conditionlabels{i,:}='dev3';
        end
    end
    
    bdf_event_table = struct2table(event_struct); 
    type = repmat({'STATUS'},length(S.conditionlabels),1) ;
    value = cell(length(S.conditionlabels),1);
    offset = cell(length(S.conditionlabels),1);
    duration = num2cell(ones(length(S.conditionlabels),1)*0.5*fs);
    sample = S.trl(:,1);
    
    generated_event_table = table(type,sample,value,offset,duration);
    event_table = [bdf_event_table;generated_event_table];
    
    event_table.delay = ones(length(event_struct)+length(S.conditionlabels),1)*delay/1000;
    event_table.conditionlabel = [cell(length(event_struct),1); S.conditionlabels(:)];
    event_table.rand_ISI = [cell(length(event_struct),1); rand_ISI'];
    event_table.start_samples = [cell(length(event_struct),1); start_samples'];

    cfg.events = table2struct(event_table);

    
    data2bids(cfg);
    
    end
end


%% Write events.json 

%read from txt 
event_txt_file = 'MMN_events.txt';
fid = fopen(fullfile(data_dir,event_txt_file), 'r');
assert(fid~=-1,sprintf('Could not open %s',event_txt_file))

txtC = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
MMN_events  = txtC{1};
fclose(fid);

MMN_split = cellfun(@(x) split(x,char(9)),MMN_events,'UniformOutput',0);

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
    cfg.TaskEventsDescription.conditionlabel.Levels = '????';
    
    cfg.TaskEventsDescription.rand_ISI.Description = '????';
    cfg.TaskEventsDescription.rand_ISI.Units = '????';
    
    cfg.TaskEventsDescription.start_samples.Description = '????';
    cfg.TaskEventsDescription.start_samples.Units = '????';
    
    desc = sprintf('The value characterizing the event. These are the values to %s, and the description of these values includes information about %s',MMN_split{1}{end},MMN_split{1}{1});
    cfg.TaskEventsDescription.value.Description = desc;
    
    notes ='';
    for s = 2:length(MMN_split)
        level_key = MMN_split{s}{end};
        if ~isnan(str2double(level_key))
            cfg.TaskEventsDescription.value.Levels.(strcat('Int_',level_key)) = MMN_split{s}{1};
        else
            notes = strcat(notes,' ',level_key);
        end
    end
    
    cfg.TaskEventsDescription.Notes = strcat(notes,' The variables from subject_*SUB_ID*_MMN_triggers.mat files are added to the events.tsv files as start_sample -> start_sample, rand_ISI -> rand_ISI, mmn-codes -> conditionlabels.');
    
    cfg.TaskEventsDescription.StimulusPresentation = '????';
    
    fn = fieldnames(cfg.TaskEventsDescription);
    TaskEventsDescription_settings = keepfields(cfg.TaskEventsDescription, fn);
    ft_write_json(filename, TaskEventsDescription_settings);
end


subs = [sub,existing_sub];

for ii = 1:length(subs)
    for jj = 1:length(ses)
        
        described_vars=fieldnames(cfg.TaskEventsDescription);
        var_names = readtable(fullfile(bids_dir,sprintf('sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-%s_events.tsv',subs{ii},ses{jj},subs{ii},ses{jj},task)),'FileType','text').Properties.VariableNames;

        non_described_var_idx = ~ismember(var_names,described_vars);
        
        if any(non_described_var_idx)
            non_described_vars = var_names(non_described_var_idx);
            fprintf('The file %s is missing a description for the ',filename)
            fprintf('%s variable, ',non_described_vars{:})
            fprintf('for subject %s in session %s\n',subs{ii},ses{jj})
        end
    end
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

%also copy BIDS validator, json fix scripts and job script 
if strcmp(run_mode,'new_BIDS')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/BIDS_validator_EEG.py'), fullfile(code_dir,'/BIDS_validator_EEG.py'), 'f')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/change_json_int_keys.py'), fullfile(code_dir,'/change_json_int_keys.py'), 'f')
    %copyfile(fullfile(EEG2BIDS_tool_dir,'/EEG_Flanker_job.sh'), fullfile(code_dir,'/EEG_Flanker_job.sh'), 'f')
end


%% Copy the stimulation files to /stim direcotry

stim_dir = fullfile(bids_dir,'/stim');

if not(isfolder(stim_dir))
    mkdir(stim_dir)
end

if strcmp(run_mode,'new_BIDS')
    copyfile(fullfile(EEG2BIDS_tool_dir,'/BIDS_validator_EEG.py'), fullfile(stim_dir,'/BIDS_validator_EEG.py'), 'f')
end

