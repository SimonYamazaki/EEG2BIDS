function cp_ses_files(stim_files,bids_stim_file_path)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here

if isstruct(stim_files)
    ses = fieldnames(stim_files);
    stim_files_struct = stim_files;
else
    ses = {'None'};
    stim_files_struct.(ses{1}) = stim_files;
end

for ss = 1:length(ses)
    for sf=1:length(stim_files_struct.(ses{ss}))
        if not(isfile( bids_stim_file_path.(ses{ss}){sf} ))
            fprintf('copying %s to %s for session %s\n',stim_files_struct.(ses{ss}){sf},bids_stim_file_path.(ses{ss}){sf},ses{ss})
            copyfile( stim_files_struct.(ses{ss}){sf}, bids_stim_file_path.(ses{ss}){sf}, 'f') %copy the stim files listed in the setup to the stim directory in the bids_dir
        end
    end
end

end

