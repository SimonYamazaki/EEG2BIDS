function [sub,ses,bdf_file_names,bdf_file_folders] = define_sub_ses_bdf(varargin)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

data_dir = varargin{1};
data_file = varargin{2};
IDs = varargin{3};
vars_input = varargin{4};
if nargin >= 5
    nono_keywords_in_filename = varargin{5};
end

char_arguments = varargin(cellfun(@(c) ischar(c), varargin));
if ismember('method',char_arguments)
    search_method = varargin{find(strcmp(varargin,'method')==1)+1};
    char_idx = varargin{find(strcmp(varargin,'method')==1)+2};
end


if exist('search_method','var')
    [sub,bdf_file_names,bdf_file_folders] = find_sub_ids(data_dir, data_file, IDs, nono_keywords_in_filename,'method',search_method,char_idx);
else
    [sub,bdf_file_names,bdf_file_folders] = find_sub_ids(data_dir, data_file, IDs, nono_keywords_in_filename);
end


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

