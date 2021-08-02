function [sub,bdf_file_names] = find_sub_ids(varargin)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

data_dir = varargin{1};
file_pattern = varargin{2};
via_id = varargin{3};

ses = fieldnames(data_dir);


if nargin == 3
    nono_keywords_in_filename = {'DELETE_THIS_FILE'};
elseif nargin == 4
    nono_keywords_in_filename = varargin{4};
end

for s = 1:length(ses)
    % extract file names and subject ids 
    file_struct = dir(sprintf('%s/%s',data_dir.(ses{s}),file_pattern));
    bdf_file_names.(ses{s}) = cellstr({file_struct.name});
    sub.(ses{s}) = cell(1,length(bdf_file_names.(ses{s})));
    sub_split = cellfun(@(x) split(x,{'subject','sub','_','-','.'}),bdf_file_names.(ses{s}),'UniformOutput',0);
    
    for ii = 1:length(bdf_file_names.(ses{s}))
        if ~any(ismember(nono_keywords_in_filename,sub_split{ii})) 
            numeric_idx = cell2mat(cellfun(@(x) ~isnan(str2double(x)),sub_split{ii},'UniformOutput',0));
            db_idx = ismember(sub_split{ii},cellstr(num2str(via_id,'%03d')));
            sub.(ses{s}){ii} = sub_split{ii}{and(numeric_idx,db_idx)};
        end
    end
end

end

