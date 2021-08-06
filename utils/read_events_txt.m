function  cfg_struct = read_events_txt(cfg_struct,MMN_eventsC,extra_notes)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here
MMN_split = cellfun(@(x) split(x,char(9)),MMN_eventsC,'UniformOutput',0);

desc = sprintf('The value characterizing the event. These are the values to %s, and the description of these values includes information about %s',MMN_split{1}{end},MMN_split{1}{1});
cfg_struct.value.Description = desc;

notes ='';
for s = 2:length(MMN_split)
    level_key = MMN_split{s}{end};
    if ~isnan(str2double(level_key))
        cfg_struct.value.Levels.(strcat('Int_',level_key)) = MMN_split{s}{1};
    else
        notes = strcat(notes,' ',level_key);
    end
end

if nargin == 3
    cfg_struct.Non_column_descriptor.Notes = strcat(notes,extra_notes);
else
    cfg_struct.Non_column_descriptor.Notes = notes;
end
    
end

