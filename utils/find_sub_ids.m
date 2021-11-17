function [sub,bdf_file_names,bdf_file_folders] = find_sub_ids(data_dir, file_patterns, IDs, varargin)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

if nargin == 3
    search_method = 'auto';
    varargin_chars = {};
else
    idx = cellfun(@(c) ischar(c), varargin);
    varargin_chars = varargin(idx);
end


if ismember('nono_keyword',varargin_chars)
    nono_keywords_in_filename = varargin{find(strcmp(varargin,'nono_keyword')==1)+1};
end

if ismember('method',varargin_chars) 
    search_method = varargin{find(strcmp(varargin,'method')==1)+1};
    
    if strcmp(search_method,'manual')
        char_idx = varargin{end};
    end
end


if ismember('id_from_folder',varargin_chars)
    id_from_folder = varargin{find(strcmp(varargin,'id_from_folder')==1)+1};
end


if isstruct(data_dir)
    ses = fieldnames(data_dir);
    data_dir_ses = data_dir;
    file_patterns_ses = file_patterns;
    assert(isstruct(file_patterns) && isequal(fieldnames(file_patterns),ses),'The same sessions were not specified for the data_dir and data_file. Sessions must be identical');
    
elseif ischar(data_dir) || isstring(data_dir)
    assert(ischar(file_patterns) || isstring(file_patterns),'If no sessions are defined for the data_dir, the file_patterns can not have sessions.\n');
    ses = {'None'};
    data_dir_ses.(ses{1}) = data_dir;
    file_patterns_ses.(ses{1}) = file_patterns;
else
    fprintf('WARNING: data_dir must be a character array or string, or a struct with field names corresponding to sessions.\n')
end

for s = 1:length(ses)
    % extract file names and subject ids 
    file_struct = dir(sprintf('%s/%s',data_dir_ses.(ses{s}),file_patterns_ses.(ses{s})));
    assert(~isempty(file_struct),'No files matching the pattern %s found in %s',file_patterns_ses.(ses{s}),data_dir_ses.(ses{s}))
    
    bdf_file_names.(ses{s}) = cellstr({file_struct.name});
    folders = cellstr({file_struct.folder});
    folders = strcat(folders,'/');
    bdf_file_folders.(ses{s}) = folders;
    bdf_fullfile.(ses{s}) = strcat(folders,bdf_file_names.(ses{s}));
    
    if ismember('nono_keyword',varargin_chars)
        nono_bdf_file_idx = contains(bdf_file_names.(ses{s}),nono_keywords_in_filename);
        sub.(ses{s}) = cell(1,sum(not(nono_bdf_file_idx)));
    else
        nono_bdf_file_idx = logical(zeros(1,length(bdf_file_names.(ses{s}))));
        sub.(ses{s}) = cell(1,length(bdf_file_names.(ses{s})));
    end
    
    if id_from_folder
        file_folders = cellfun(@fileparts, bdf_fullfile.(ses{s}),'UniformOutput',0);
        [root_folder,desired_folder.(ses{s})] = cellfun(@fileparts, file_folders, 'UniformOutput', false);
        bdf_file_split = cellfun(@(x) split(x,{'subject','sub','_','-','.'}),desired_folder.(ses{s}),'UniformOutput',0);
    else
        bdf_file_split = cellfun(@(x) split(x,{'subject','sub','_','-','.'}),bdf_file_names.(ses{s}),'UniformOutput',0);
    end
    
    for ii = 1:length(bdf_file_names.(ses{s}))
        if strcmp(search_method,'auto')
            if ~nono_bdf_file_idx(ii)
                numeric_idx = cell2mat(cellfun(@(x) ~isnan(str2double(x)),bdf_file_split{ii},'UniformOutput',0));
                db_idx = ismember(bdf_file_split{ii},IDs);
                sub.(ses{s}){ii} = bdf_file_split{ii}{and(numeric_idx,db_idx)};
            else
                fprintf('WARNING: The subject file %s will NOT moved to the BIDS dataset for session %s\n',bdf_fullfile.(ses{s}){ii},ses{s})
            end
            
        elseif strcmp(search_method,'manual')
            if ~nono_bdf_file_idx(ii)
                if id_from_folder
                    sub_bdf_file = desired_folder.(ses{s}){ii};
                else
                    sub_bdf_file = bdf_file_names.(ses{s}){ii};
                end

                sub.(ses{s}){ii} = sub_bdf_file(char_idx);
            else
                fprintf('WARNING: The subject file %s will NOT moved to the BIDS dataset. A subject directory is not made in the BIDS dataset for the subject which this file belongs to\n',bdf_fullfile.(ses{s}){ii})
            end
        end
    end
    
    if ismember('id_trans',varargin_chars)
        id_trans = varargin{find(strcmp(varargin,'id_trans')==1)+1};
        sub.(ses{s}) = cellfun(@(x) id_trans(x), sub.(ses{s}),'UniformOutput',0);
    end
    
    
end %ses loop


end %function

