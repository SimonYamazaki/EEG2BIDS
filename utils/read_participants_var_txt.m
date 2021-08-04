function cfg_struct = read_participants_var_txt(cfg_struct,participants_var,participant_info_include)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here

    info_split = cellfun(@(x) split(x,':'),participants_var,'UniformOutput',0);
    valid_keys = {'LongName','Description','Levels','Units'};
    name_indices = find(contains(participants_var,'Name')==1);
    
    var_names = {};
    for n = 1:length(name_indices)
        ii = name_indices(n);
        if strcmp(info_split{ii}{1},'Name') && ismember(strtrim(info_split{ii}{2}),participant_info_include)

            for jj = 1:length(valid_keys)

                if ismember(info_split{ii+jj}{1},valid_keys) && strcmp(info_split{ii+jj}{1},'Levels')                
                    levelsC = strtrim(split(join(info_split{ii+jj}(2:end)),','));
                    split_idx = cell2mat(cellfun(@(x) x(1),strfind(levelsC,' '),'UniformOutput',0));

                    for kk = 1:length(levelsC)
                        level_key = strtrim(levelsC{kk}(1:split_idx(kk)));
                        level_value = strtrim(levelsC{kk}(split_idx(kk):end));
                        if isnan(str2double(level_key))
                            cfg_struct.(strtrim(info_split{ii}{2})).(strtrim(info_split{ii+jj}{1})).(level_key) = level_value;
                        else
                            cfg_struct.(strtrim(info_split{ii}{2})).(strtrim(info_split{ii+jj}{1})).(strcat('Int_',level_key)) = level_value;                        
                        end
                    end

                elseif ismember(info_split{ii+jj}{1},valid_keys)
                    cfg_struct.(strtrim(info_split{ii}{2})).(strtrim(info_split{ii+jj}{1})) = strtrim(info_split{ii+jj}{2});
                end
                
                if (ii+jj==length(info_split)) 
                    break;
                end
            end

            %var_names{end+1}=strtrim(info_split{ii}{2});
        end

    end
    
    
    
    
    
end

