function [bids_stim_file_path, bids_stim_file_name] = get_bids_stim_files(stim_files,stim_dir)
%UNTITLED4 Summary of this function goes here
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
        [folder,name,ext] = fileparts(stim_files_struct.(ses{ss}){sf});
        bids_stim_file_name.(ses{ss}){sf} = strcat(name,ext); %the name of the stim files 
        bids_stim_file_path.(ses{ss}){sf} = fullfile(stim_dir,bids_stim_file_name.(ses{ss}){sf}); %the stim file paths in the bids_dir
    end
end
    
end

