function cmp_and_print_subs_with_file(sub,subs_with_additional_files,must_exist_files,ses)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here

must_exist_file_names = must_exist_files;

for s = 1:length(ses)
    file_names = fieldnames(subs_with_additional_files.(ses{s}));
    for f = 1:length(file_names)
        fn = file_names{f};
        mefn = must_exist_file_names.(ses{s}){f};
        
        subs_with_file = subs_with_additional_files.(ses{s}).(fn);
        if all(ismember(sub.(ses{s}),subs_with_file)) && length(sub.(ses{s}))==1
            fprintf('Subject %s with data file also have %s files in session %s\n',sub.(ses{s}){1},mefn,ses{s})
        elseif all(ismember(sub.(ses{s}),subs_with_file)) && length(sub.(ses{s}))>1
            fprintf('All subjects with data files also have %s files in session %s\n',mefn,ses{s})
        elseif any(not(ismember(sub.(ses{s}),subs_with_file)))
            %subsid = sub.(ses{s}){~ismember(sub.(ses{s}),subs_with_file)};
           % 
            %for i = 1:length(subsid)
            %    fprintf('WARNING: Subject %s has data file but are missing a %s file in session %s\n',subsid(i),mefn,ses{s} )
            %end
            fprintf('WARNING: Subject %s has data file but are missing a %s file in session %s\n',sub.(ses{s}){~ismember(sub.(ses{s}),subs_with_file)},mefn,ses{s} )
        elseif any(not(ismember(subs_with_file,sub.(ses{s}))))
            fprintf('WARNING: Subject %s has %s file but are missing data file in session %s\n',subs_with_file{~ismember(subs_with_file,sub.(ses{s}))},mefn,ses{s} )
        else
            fprintf('WARNING: Did not find match between subjects with data files and subjects with %s files. Check if file search pattern is correct for session %s\n',mefn,ses{s})
        end
    end
end
end

