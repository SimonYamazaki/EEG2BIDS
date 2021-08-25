%%%%%% EVENTS FROM ASSR_reg


%search pattern for data files
data_file.via11 = '*_ASSR_reg*.bdf';
data_file.via15 = '*_ASSR_reg*.bdf';
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
stim_files = {'/home/simonyj/EEG_ASSR_reg/click_40_regular.wav'};

%txt file paths to be read
event_txt_file = fullfile(data_dir.via11,'ASSR_events.txt');
instructions_txt = fullfile(data_dir.via11,'ASSR_reg_instructions.txt');
participants_var_txt = fullfile(data_dir.via11,'participants_variables.txt');




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

    event_table.stim_file = [cell(length(event_struct),1); repmat(bids_stim_file_name(1),length(conditionlabels),1)];
    event_table.delay = ones(length(event_struct)+length(conditionlabels),1)*delay/1000;
    event_table.conditionlabel = [cell(length(event_struct),1); conditionlabels(:)];

    cfg.events = table2struct(event_table);
    cfg.keep_events_order = true; %should the events be sorted according to sample or should it keep the order of the table?
    
    data2bids(cfg);



%% %%%%%%%%%%%%%%%%% BEHAV  %%%%%%%%%%%%%%%%%%%%%%

behav_path = '/mnt/projects/VIA11/EEG/Anna/Flanker/Input_behavdata_Excel/Flankerbehav090119.xls';
behav_col_names_path = '/mnt/projects/VIA11/EEG/Data/Flanker_47condition/EEG_Flanker.txt';

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


%%% to go into the data2bids loop

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



%% %%%%%%%%%%%%%%%%% ELECTRODES  %%%%%%%%%%%%%%%%%%%%%%



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