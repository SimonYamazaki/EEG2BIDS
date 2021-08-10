function cmp_and_print_subs_with_file(sub,subs_with_additional_files,ses)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here

for s = 1:length(ses)
    fnames = fieldnames(subs_with_additional_files);
    for f = 1:length(fnames)
        fn = fnames{f};
        subs_with_file = subs_with_additional_files.(fn).(ses{s});
        if all(ismember(sub.(ses{s}),subs_with_file))
            fprintf('All subjects with data files also have %s files in session %s\n',fn,ses{s})
        elseif length(sub.(ses{s}))==length(subs_with_file) && ~isequal(sub.(ses{s}),subs_with_file)
            fprintf('Did not find match between subjects with data files and subjects with %s files. Check if subject ID search pattern is correct for session %s\n',fn,ses{s})
        elseif any(not(ismember(sub.(ses{s}),subs_with_file)))
            fprintf('Subject %s has data file but are missing a %s file in session %s\n',sub.(ses{s}){~ismember(sub.(ses{s}),subs_with_file)},fn,ses{s} )
        elseif any(not(ismember(subs_with_file,sub.(ses{s}))))
            fprintf('Subject %s has %s file but are missing data file in session %s\n',subs_with_file{~ismember(subs_with_file,sub.(ses{s}))},fn,ses{s} )
        end
    end
end
end

