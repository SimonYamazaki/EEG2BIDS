function [sub,ses,bdf_file_names] = define_sub_ses_bdf(varargin)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

data_dir = varargin{1};
vars_input = varargin{2};
data_file = varargin{3};
via_id = varargin{4};
this_file_path = varargin{5};
if nargin >= 6
    nono_keywords_in_filename = varargin{6};
end

char_arguments = varargin(cellfun(@(c) ischar(c), varargin));
if ismember('method',char_arguments)
    search_method = varargin{find(strcmp(varargin,'method')==1)+1};
    char_idx = varargin{end};
end


if exist('search_method','var')
    [sub,bdf_file_names] = find_sub_ids(data_dir, data_file, via_id, nono_keywords_in_filename,'method',search_method,char_idx);
else
    [sub,bdf_file_names] = find_sub_ids(data_dir, data_file, via_id, nono_keywords_in_filename);
end


if length(vars_input) == 2
    if isstruct(data_dir)
        n_ses = length(fieldnames(data_dir));
        assert(n_ses==1,sprintf('No session is specified, however, the script %s has %i session path(s)\n',this_file_path,n_ses))
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

