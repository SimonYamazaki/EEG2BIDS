function [existing_sub] = find_existing_subs(bids_dir,files_checked,ses)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here


%find already existing subs by subject folders
sub_dirs = dir(sprintf('%s/sub-*',bids_dir));
file_dirs = cellstr({sub_dirs.name});
existing_sub = cellfun(@(x) x(end-2:end),file_dirs,'un',0);

%check that the subjects with existing sub folders have the needed files 
for f = 1:length(files_checked)
    
    if nargin == 3
        for s = 1:length(ses)
            sub_dirs = {dir(sprintf('%s/*/ses-%s/*/*_%s',bids_dir,ses{s},files_checked{f})).name};

            subs_with_file = cellfun(@(x) x(5:7),sub_dirs,'un',0);

            if any(~ismember(existing_sub,subs_with_file))
                sub2redo = existing_sub{~ismember(existing_sub,subs_with_file)};
                existing_sub(strcmp(existing_sub,sub2redo))=[];
                fprintf('Subject %s is missing a %s file from session %s\n',sub2redo,files_checked{f},ses{s})
            end
        end
        
    else
        
        sub_dirs = {dir(sprintf('%s/**/*_%s',bids_dir,files_checked{f})).name};
        subs_with_file = cellfun(@(x) x(5:7),sub_dirs,'un',0);
        
        if any(~ismember(existing_sub,subs_with_file))
            sub2redo = existing_sub{~ismember(existing_sub,subs_with_file)};
            existing_sub(strcmp(existing_sub,sub2redo))=[];
            fprintf('Subject %s is missing a %s file\n',sub2redo,files_checked{f})
        end
        
    end
    

end

end

