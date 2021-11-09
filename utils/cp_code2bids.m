function cp_code2bids(init,code_file_paths)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here

code_dir = fullfile(init.bids_dir,'/code');

if not(isfolder(code_dir))
    mkdir(code_dir)
end

for file = 1:length(code_file_paths)
    [folder,name,ext]=fileparts(code_file_paths{file});
    copyfile(code_file_paths{file}, fullfile(code_dir,strcat(name,ext)), 'f')
end


end

