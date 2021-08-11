function [sub,bdf_file_names] = find_sub_ids(varargin)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

data_dir = varargin{1};
file_pattern = varargin{2};
via_id = varargin{3};

if nargin == 3
    nono_keywords_in_filename = {'%%€264#&#%(/()&%€#!'}; %random string
    search_method = 'auto';
elseif nargin == 4
    nono_keywords_in_filename = varargin{4};
    search_method = 'auto';
elseif ismember('method',varargin) && nargin == 6
    nono_keywords_in_filename = {'%%€264#&#%(/()&%€#!'}; %random string
    search_method = varargin{find(strcmp(varargin,'method')==1)+1};
    char_idx = varargin{end};
elseif ismember('method',varargin) && nargin == 7
    nono_keywords_in_filename = varargin{4};
    search_method = varargin{find(strcmp(varargin,'method')==1)+1};
    char_idx = varargin{end};
else
    fprintf('Missing arguments to find_sub_ids function')
end


if ~isstruct(data_dir)
    ses = {'None'};
    data_dir.(ses{1}) = data_dir;
elseif isstruct(data_dir)
    ses = fieldnames(data_dir);
end

for s = 1:length(ses)
    % extract file names and subject ids 
    file_struct = dir(sprintf('%s/%s',data_dir.(ses{s}),file_pattern));
    bdf_file_names.(ses{s}) = cellstr({file_struct.name});
    nono_bdf_file_idx = contains(bdf_file_names.(ses{s}),nono_keywords_in_filename);
    sub.(ses{s}) = cell(1,sum(not(nono_bdf_file_idx)));
    bdf_file_split = cellfun(@(x) split(x,{'subject','sub','_','-','.'}),bdf_file_names.(ses{s}),'UniformOutput',0);
    for ii = 1:length(bdf_file_names.(ses{s}))
        if strcmp(search_method,'auto')
            if ~nono_bdf_file_idx(ii)
                numeric_idx = cell2mat(cellfun(@(x) ~isnan(str2double(x)),bdf_file_split{ii},'UniformOutput',0));
                db_idx = ismember(bdf_file_split{ii},cellstr(num2str(via_id,'%03d')));
                sub.(ses{s}){ii} = bdf_file_split{ii}{and(numeric_idx,db_idx)};
            else
                fprintf('WARNING: The subject file %s is NOT moved to the BIDS dataset for session %s. A subject directory is not made in the BIDS dataset for the subject which this file belongs to\n',bdf_file_names.(ses{s}){ii},ses{s})
            end
            
        elseif strcmp(search_method,'manual')
            if ~nono_bdf_file_idx(ii)
                sub_bdf_file = bdf_file_names.(ses{s}){ii};
                sub.(ses{s}){ii} = sub_bdf_file(char_idx);
            else
                fprintf('WARNING: The subject file %s is NOT moved to the BIDS dataset. A subject directory is not made in the BIDS dataset for the subject which this file belongs to\n',bdf_file_names.(ses{s}){ii})
            end
        end
    end
end


end

