function cfg = configure_input(cfg,input)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

    sesindx = cfg.sesindx;
    subindx = cfg.subindx;
    
    % specify the output directory (bids_dir)
    cfg.bidsroot  = input.init.bids_dir;
    
    %By default if no session is specified, the cell array "ses" is named
    %'None' through functions in the EEG2BIDS_tool_dir
    if ~strcmp(input.ses{sesindx},'None')
        cfg.ses       = input.ses{sesindx};
    end
    
    % get subject ID 
    cfg.file_sub_id  = input.sub.(input.ses{sesindx}){subindx};
    cfg.sub          = strcat(input.init.ID_prefix, input.sub.(input.ses{sesindx}){subindx});
    
    %specify whether files should be included
    cfg.include_scans = input.init.include_scans_tsv;
    cfg.write_events_tsv = input.init.include_events_tsv;
        
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

end

