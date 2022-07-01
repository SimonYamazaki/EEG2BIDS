function [subs_with_all_files,subs_with_files,additional_file_names] = search_must_exist_files(data_dir,IDs,must_exist_files,must_exist_files_id_search,id_from_folder)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here
inputs_to_find_sub_ids = {};
inputs_to_find_sub_ids{end+1} = 'id_from_folder'; 
inputs_to_find_sub_ids{end+1} = id_from_folder;

inputs_to_find_sub_ids{end+1} = 'method';
search_method = must_exist_files_id_search{1};
inputs_to_find_sub_ids{end+1} = search_method;
if strcmp(search_method,'manual')
    char_idx = must_exist_files_id_search{2};
    inputs_to_find_sub_ids{end+1} = char_idx;
end

if isstruct(must_exist_files)
    ses = fieldnames(must_exist_files);
else
    ses = {'None'};
end


for s = 1:length(ses)
    for f = 1:length(must_exist_files.(ses{s}))
        %if length(ses) > 1
        ses_to_rm = ses(~ismember(ses,ses(s)));
        data_dir_single_ses = rmfield(data_dir, ses_to_rm);

        must_exist_files_tmp = must_exist_files;
        must_exist_files_tmp.(ses{s}) = must_exist_files_tmp.(ses{s}){f};
        must_exist_files_struct = rmfield(must_exist_files_tmp, ses_to_rm);
        %end
        
        %[subs_with_additional_files.(strcat('file',num2str(f))),additional_file_names.(strcat('file',num2str(f)))] = find_sub_ids(data_dir_single_ses, must_exist_files_struct, IDs, inputs_to_find_sub_ids{:});
        folder = must_exist_files_struct.(ses{s}); %must_exist_files.(ses{s});
        while ismember('*',folder) == true
            [folder,filename,ext] = fileparts(folder);
        end
        
        data_dir_single_ses.(ses{s}) = folder;
        
        path_split=split(must_exist_files_struct.(ses{s}),folder);
        file_pattern.(ses{s}) = path_split{2};
        
        if s>1
            file_pattern = rmfield(file_pattern, ses_to_rm);
        end
        
        [subs_with_additional_files.(strcat('file',num2str(f))),additional_file_names.(strcat('file',num2str(f)))] = find_sub_ids(data_dir_single_ses, file_pattern, IDs, inputs_to_find_sub_ids{:});
        subs_with_files.(ses{s}).(strcat('file',num2str(f))) = subs_with_additional_files.(strcat('file',num2str(f))).(ses{s});
    end

    %check if subs have all files
    subs_with_files_vec.(ses{s}) = cell('');
    for ff = 1:length(must_exist_files.(ses{s}))
        subs_with_files_vec.(ses{s}) = [subs_with_files_vec.(ses{s}),subs_with_files.(ses{s}).(strcat('file',num2str(f)))];
    end
    
    subs_with_all_files.(ses{s}) = cell('');
    subs = unique(subs_with_files_vec.(ses{s}));
    for ss = 1:length(subs)
        if sum(ismember(subs_with_files_vec.(ses{s}),subs{ss}))==length(must_exist_files.(ses{s}))
            subs_with_all_files.(ses{s}){end+1} = subs{ss};
        end
    end
end


end

