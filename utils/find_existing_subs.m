function [existing_sub] = find_existing_subs(varargin)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

bids_dir = varargin{1};
files_checked_input = varargin{2};

%find already existing subs by subject folders
sub_dirs = dir(sprintf('%s/sub-*',bids_dir));
file_dirs = cellstr({sub_dirs.name});
existing_sub_root = cellfun(@(x) x(end-2:end),file_dirs,'un',0);

if nargin > 2
    ses = varargin{3};
    for ii = 1:length(ses)
        existing_sub.(ses{ii}) = existing_sub_root;
        if isstruct(files_checked_input)
            assert( ismember(ses(ii),fieldnames(files_checked_input)),sprintf('Session %s is not defined in the "files_checked" structure varaible',ses{ii}));
            files_checked.(ses{ii}) = files_checked_input.(ses{ii});
        else
            files_checked.(ses{ii}) = files_checked_input;            
        end
    end
    
else
    ses = {'None'};
    existing_sub.(ses{1}) = existing_sub_root;
    files_checked.(ses{1}) = files_checked_input;
end


%check that the subjects with existing sub folders have the needed files 
for f = 1:length(files_checked)
    
    for s = 1:length(ses)
        
        if strcmp(ses{s},'None')
            sub_dirs = {dir(sprintf('%s/**/*_%s',bids_dir,files_checked.(ses{s}){f})).name};
        else
            sub_dirs = {dir(sprintf('%s/*/ses-%s/*/%s',bids_dir,ses{s},files_checked.(ses{s}){f})).name};
        end
        
        subs_with_file = cellfun(@(x) x(5:7),sub_dirs,'un',0);

        if any(~ismember(existing_sub.(ses{s}),subs_with_file))
            sub2redo = existing_sub.(ses{s})(~ismember(existing_sub.(ses{s}),subs_with_file));
            
            existing_sub.(ses{s})(ismember(existing_sub.(ses{s}),sub2redo))=[];
            
%             for sub = 1:length(sub2redo)
%                 if strcmp(ses{s},'None')
%                     fprintf('WARNING: Subject %s is missing a %s file\n',sub2redo{sub},files_checked.(ses{s}){f})
%                 else
%                     fprintf('WARNING: Subject %s is missing a %s file in session %s\n',sub2redo{sub},files_checked.(ses{s}){f},ses{s})
%                 end
%             end
        end
    end
end


end

