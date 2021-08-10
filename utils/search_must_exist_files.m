function subs_with_additional_files = search_must_exist_files(data_dir,via_id,must_exist_files)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

for f = 1:length(must_exist_files)
    must_exist_file_fieldname_cell = cellfun(@(x) split(x,{'.','*','-','_'}),must_exist_files,'UniformOutput',0);
    must_exist_file_fieldname = must_exist_file_fieldname_cell{f}{end-1};
    [subs_with_additional_files.(must_exist_file_fieldname),additional_file_names] = find_sub_ids(data_dir,must_exist_files{f},via_id);
end

end

