function [subs_with_all_files,subs_with_files,additional_file_names] = search_must_exist_files(data_dir,via_id,must_exist_files)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

if isstruct(must_exist_files)
    ses = fieldnames(must_exist_files);
else
    ses = {'None'};
end


for s = 1:length(ses)
    for f = 1:length(must_exist_files.(ses{s}))
        if length(ses) > 1
            ses_to_rm = ses(~ismember(ses,ses(s)));
            data_dir_single_ses = rmfield(data_dir, ses_to_rm);
            
            must_exist_files_tmp = must_exist_files;
            must_exist_files_tmp.(ses{s}) = must_exist_files_tmp.(ses{s}){f};
            must_exist_files_struct = rmfield(must_exist_files_tmp, ses_to_rm);
        end
        
        %must_exist_file_fieldname_cell = cellfun(@(x) split(x,{'.','*','-','_'}),{must_exist_files_struct.(ses{s})},'UniformOutput',0);
        %must_exist_file_fieldname = strcat(must_exist_file_fieldname_cell{f}{end-1},num2str(f));
        [subs_with_additional_files.(strcat('file',num2str(f))),additional_file_names.(strcat('file',num2str(f)))] = find_sub_ids(data_dir_single_ses, must_exist_files_struct, via_id);
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

