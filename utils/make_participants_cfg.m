function cfg_participants = make_participants_cfg(cfg,input)
%UNTITLED8 Summary of this function goes here
%   Detailed explanation goes here

sub_info_table = input.init.sub_info_table;
IDs = input.init.IDs;
file_sub_id = cfg.file_sub_id;

if isfield(input.init,'participant_info_include')
    nargin = 4;
    participant_info_include = input.init.participant_info_include;
else
    nargin = 3;
end


col_names = sub_info_table.Properties.VariableNames;
total_cols = width(sub_info_table);
sub_info_table = table2cell(sub_info_table);

for col = 1:total_cols
    if nargin == 4
        if contains(col_names{col},participant_info_include)
            cfg_participants.(col_names{col}) = sub_info_table{strcmp(IDs,file_sub_id),col};
        elseif contains(col_names{col},participant_info_include) && isdatetime(sub_info_table{strcmp(IDs,file_sub_id),col}) && isnat(sub_info_table{strcmp(IDs,file_sub_id),col})
            cfg_participants.(col_names{col}) = 'n/a';
        elseif contains(col_names{col},participant_info_include) && isdatetime(sub_info_table{strcmp(IDs,file_sub_id),col})
            cfg_participants.(col_names{col}) = strrep(char(sub_info_table{strcmp(IDs,file_sub_id),col}),'/','-');
        elseif contains(col_names{col},participant_info_include) && isnumeric(sub_info_table{strcmp(IDs,file_sub_id),col}) && isnan(sub_info_table{strcmp(IDs,file_sub_id),col})
            cfg_participants.(col_names{col}) = 'n/a';
        end

    elseif nargin == 3 %if all column should be included
        if isdatetime(sub_info_table{via_id==sub_int,col}) && isnat(sub_info_table{strcmp(IDs,file_sub_id),col})
            cfg_participants.(col_names{col}) = 'n/a';
        elseif isdatetime(sub_info_table{strcmp(IDs,file_sub_id),col})
            cfg_participants.(col_names{col}) = strrep(char(sub_info_table{strcmp(IDs,file_sub_id),col}),'/','-');
        elseif isnumeric(sub_info_table{strcmp(IDs,file_sub_id),col}) && isnan(sub_info_table{strcmp(IDs,file_sub_id),col})
            cfg_participants.(col_names{col}) = 'n/a';
        else
            cfg_participants.(col_names{col}) = sub_info_table{strcmp(IDs,file_sub_id),col};
        end
    end
    
end

end

