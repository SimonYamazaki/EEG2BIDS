function  cfg_struct = read_events_txt(eventsC)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here
event_split = cellfun(@(x) split(x,char(9)),eventsC,'UniformOutput',0);

desc = sprintf('The value characterizing the event. These are the values to %s, and the description of these values includes information about %s',event_split{1}{end},event_split{1}{1});
cfg_struct.value.Description = desc;

notes ='';
for s = 2:length(event_split)
    level_key = event_split{s}{end};
    if ~isnan(str2double(level_key))
        cfg_struct.value.Levels.(strcat('Int_',level_key)) = event_split{s}{1};
    else
        notes = strcat(notes,' ',level_key); %everything else
    end
end

    
end

