function  non_described_vars = check_described_variables_in_tsv(bids_dir,cfg_struct,sub_input,tsv_file)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here
clear non_described_vars

if ~isstruct(sub_input)
    ses = {'one_ses'};
    sub.(ses{1}) = sub_input;
elseif isstruct(sub_input)
    sub = sub_input;
    ses = fieldnames(sub);
end

file_struct = dir(sprintf('%s/**/*%s',bids_dir,tsv_file));
folders={file_struct.folder};
tsv_names={file_struct.name};
multiple_tsv_paths = fullfile(folders,tsv_names); 

if length(multiple_tsv_paths)==1
    single_file = true;
else
    single_file = false;
end

for jj = 1:length(ses)
    for ii = 1:length(sub.(ses{jj}))
    
        described_vars=fieldnames(cfg_struct);
        
        if single_file
            tsv_path = multiple_tsv_paths;
        else
            sub_tsv_paths = multiple_tsv_paths(contains(multiple_tsv_paths,sub.(ses{jj}){ii}));
            tsv_path = sub_tsv_paths(contains(sub_tsv_paths,ses{jj}));
        end
        
        assert(length(tsv_path) == 1,sprintf('Found multiple %s files. If more than one modality is present with a %s file, this function must be updated',tsv_file,tsv_file));
        %path_split = cellfun(@(x) split(x,{'/'}),tsv_path,'UniformOutput',0);
        %modality=path_split{1}{end-1}
        
        var_names = readtable(tsv_path{1},'FileType','text').Properties.VariableNames;
        
        non_described_var_idx = ~ismember(var_names,described_vars);
        
        if any(non_described_var_idx)
            non_described_vars.(ses{jj}).(strcat('sub_',sub.(ses{jj}){ii})) = var_names(non_described_var_idx);
            fprintf('The file %s is missing a description for the variable(s) ',tsv_path{1})
            fprintf('%s, ',non_described_vars.(ses{jj}).(strcat('sub_',sub.(ses{jj}){ii})){:})
            fprintf('for subject %s in session %s\n',sub.(ses{jj}){ii},ses{jj})
        end
    end
end

if ~exist('non_described_vars')
    non_described_vars = 'None';
end

end

