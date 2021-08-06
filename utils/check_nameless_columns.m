function nameless_cols = check_nameless_columns(T,behav_path)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here
var_names = T.Properties.VariableNames;
if any(contains(var_names,'Var'))
    clear nameless_cols
    var_number = find(contains(var_names,'Var'));
    potential_nameless_cols = var_names(contains(var_names,'Var'));

    for c = 1:length(potential_nameless_cols)
        if strcmp( potential_nameless_cols{c},sprintf('Var%s',num2str(var_number(c))) )
            if exist('nameless_cols')
                nameless_cols = [nameless_cols,c]; 
            else
                nameless_cols = c;
            end
        end
    end
    
else
    nameless_cols = '';
end
end

