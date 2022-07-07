function cfg = configure_input(cfg,input)
    
    if isfield(input.init,'dataset_description')
        input.init.write_dataset_description = true;
        fn = fields(input.init.dataset_description);
        for ii=1:length(fn)
            cfg.dataset_description.(fn{ii}) = input.init.dataset_description.(fn{ii});
        end
    else
        input.init.write_dataset_description = false;        
    end
    
    sesindx = cfg.sesindx;
    subindx = cfg.subindx;
    
    if not(isfield(cfg,'bids_datatype')) || strcmp(cfg.bids_datatype,'raw')
        %specify that the data is eeg 
        cfg.datatype  = 'eeg'; 
    
        % specify the output directory (bids_dir)
        cfg.bidsroot  = input.init.bids_dir;
        
    elseif strcmp(cfg.bids_datatype,'source')
        sourcedata_dir = fullfile(input.init.bids_dir,'/sourcedata');
        cfg.bidsroot  = sourcedata_dir;
        
        if not(isfolder(sourcedata_dir))
            mkdir(sourcedata_dir)
        end
        
    elseif strcmp(cfg.bids_datatype,'derivatives')
        deriv_dir = fullfile(input.init.bids_dir,'/derivatives');
        cfg.bidsroot  = deriv_dir;

        if not(isfolder(deriv_dir))
            mkdir(deriv_dir)
        end
    end
    
    
    
    %By default if no session is specified, the cell array "ses" is named
    %'None' through functions in the EEG2BIDS_tool_dir
    if ~strcmp(input.ses{sesindx},'None')
        cfg.ses       = input.ses{sesindx};
    end
    
    % get subject ID 
    cfg.file_sub_id  = input.sub.(input.ses{sesindx}){subindx};
    
    if isfield(input.init, 'ID_prefix')
        cfg.sub          = strcat(input.init.ID_prefix, input.sub.(input.ses{sesindx}){subindx});
    else
        cfg.sub          = strcat(input.sub.(input.ses{sesindx}){subindx});  
    end
    
    %specify whether files should be included
    cfg.include_scans = input.init.include_scans_tsv;
    
    if isfield(input.init,'include_events_tsv')
        cfg.write_events_tsv = input.init.include_events_tsv;
    else
        cfg.write_events_tsv = false;
    end
    
    if isfield(input.init,'include_participants_tsv')
        cfg.write_participants_tsv = input.init.include_participants_tsv;
    else
        cfg.write_participants_tsv = true;
    end    
    
    if isfield(input.init,'channels_in_sub_dir') && isfield(input.init,'include_task_name')
        cfg.channels_in_sub_dir = input.init.channels_in_sub_dir;
        cfg.include_task_name = input.init.include_task_name;
    else
        cfg.channels_in_sub_dir = false;
        cfg.include_task_name = true;
    end

    % define data file for current subject in loop
    if isstruct(input.init.data_dir)
        cfg.dataset   = char(fullfile(input.bdf_file_folders.(input.ses{sesindx}){subindx}, input.bdf_file_names.(input.ses{sesindx}){subindx}));
    else
        cfg.dataset   = char(fullfile(input.bdf_file_folders{subindx}, input.bdf_file_names.(input.ses{sesindx}){subindx}));
    end
    
    %%%%% Write events.json %%%%%% 
    if input.init.events_in_sub_dir 
        %the name of the events.json 
        %place the events.json in subject directory if events_in_sub_dir is true
        if isstruct(input.init.data_dir)
            cfg.event_json_file = fullfile(input.init.bids_dir, sprintf('/sub-%1$s/ses-%2$s/%3$s/sub-%1$s_ses-%2$s_task-%4$s_events.json',cfg.sub,input.ses{sesindx},cfg.datatype,input.init.task));
        else
            cfg.event_json_file = fullfile(input.init.bids_dir, sprintf('/sub-%1$s/%2$s/sub-%1$s_task-%3$s_events.json',cfg.sub,cfg.datatype,input.init.task));
        end
    else
        %place the events.json in bids_dir if events_in_sub_dir is false.
        cfg.event_json_file = fullfile(input.init.bids_dir, sprintf('task-%s_events.json',input.init.task));
    end
    
    %include the instructions if they are read
    if isfield(input,'InstructionsC')
        cfg.eeg.Instructions          = input.InstructionsC{1};
    end
    
    if isfield(input.init,'event_txt_file')
        %read txt to a cell 
        eventsC = read_txt(input.init.event_txt_file);
        
        %write info from the event_txt_file with a specific formating
        %add value and notes to the event.json  
        cfg.event_json_struct = read_events_txt(eventsC);
    end
    
    if isfield(input.init,'extra_notes')
        cfg.event_json_struct.Additional_notes_to_event_tsv.Notes = input.init.extra_notes;
    end
    
    %set default
    cfg.keep_events_order = true;
end

