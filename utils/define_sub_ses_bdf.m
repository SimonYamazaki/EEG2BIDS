function [sub,ses,bdf_file_names,bdf_file_folders] = define_sub_ses_bdf(init)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

data_dir = init.data_dir;
data_file = init.data_file;
IDs = init.IDs;
vars_input = init.varargin;

inputs_to_find_sub_ids = {data_dir,data_file,IDs,vars_input};

if isfield(init,'nono_keywords_in_filename')
    inputs_to_find_sub_ids{end+1} = init.nono_keywords_in_filename;
end

if isfield(init,'id_trans')
    inputs_to_find_sub_ids{end+1} = init.id_trans;
end

inputs_to_find_sub_ids{end+1} = 'id_from_folder';
inputs_to_find_sub_ids{end+1} = init.id_from_data_file_folder;

if isfield(init,'id_search_method')
    inputs_to_find_sub_ids{end+1} = 'method';
    search_method = init.id_search_method{1};
    inputs_to_find_sub_ids{end+1} = search_method;
    
    if strcmp(search_method,'manual')
        char_idx = init.id_search_method{2};
        inputs_to_find_sub_ids{end+1} = char_idx;
    end
else
    assert(isfield(init,'id_search_method'),'A search method was not defined, which is needed if data_dir is specified to know how to extract ids.')
end

[sub,bdf_file_names,bdf_file_folders] = find_sub_ids(inputs_to_find_sub_ids{:});


if length(vars_input) == 2
    if isstruct(data_dir)
        n_ses = length(fieldnames(data_dir));
        assert(n_ses==1,sprintf('No session is specified, however, the executed script has %i session path(s)\n',n_ses))
    else
        ses = {'None'};
        sub_idx = ismember(sub.(ses{1}),vars_input{2});
        new_bdf_file_name = bdf_file_names.(ses{1})(sub_idx);
        clear sub bdf_file_names
        sub.(ses{1}) = vars_input(2);
        bdf_file_names.(ses{1}) = new_bdf_file_name;
        fprintf('Only processing subject %s\n',sub.(ses{1}){1})
    end
    
elseif length(vars_input) == 3
    ses = {char(vars_input{3})};
    sub_idx = ismember(sub.(ses{1}),vars_input{2});
    new_bdf_file_name = bdf_file_names.(ses{1})(sub_idx);
    clear sub bdf_file_names
    sub.(ses{1}) = vars_input(2);
    bdf_file_names.(ses{1}) = new_bdf_file_name;
    fprintf('Only processing subject %s for session %s\n',sub.(ses{1}){1},ses{1})  
else
    if isstruct(data_dir)
        ses = fieldnames(data_dir);
    else
        ses = {'None'};
    end
end

end

