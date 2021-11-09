function write_participants_json(init)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here

%any additional info to include in json
cfg.ParticipantsDescription.participant_id.Description = 'Unique identifier of the subject';

%read from txt 
participants_var = read_txt(init.participants_var_txt);

%read the participants_var as a cell into the config struct
ParticipantsDescription = read_participants_var_txt(ParticipantsDescription,participants_var,init.participant_info_include);

%write the file 
participants_json = fullfile(init.bids_dir, 'participants.json');
fn = fieldnames(ParticipantsDescription);
ParticipantsDescription_settings = keepfields(ParticipantsDescription, fn);
ft_write_json(participants_json, ParticipantsDescription_settings);
fprintf('writing %s\n',participants_json)

end

