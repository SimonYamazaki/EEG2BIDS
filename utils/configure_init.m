function [input] = configure_init(init)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

if not(isfolder(init.bids_dir))
    mkdir(init.bids_dir)
end

%add paths to relevant toolboxes
if isfield(init,'EEG2BIDS_tool_dir')
    addpath([init.EEG2BIDS_tool_dir,'/utils/'])
end

%add paths to relevant toolboxes
if isfield(init,'fieldtrip_dir')
    addpath([init.fieldtrip_dir,'/'])
    addpath([init.fieldtrip_dir,'/fileio/'])
    addpath([init.fieldtrip_dir,'/utilities/'])
end


if isfield(init,'participant_id_trans')
    init.IDs_cell = cell(1,length(init.IDs));
    
    for ii = 1:length(init.IDs)
        if iscell(init.IDs)
            init.IDs_cell{ii} = init.participant_id_trans(init.IDs{ii});
        elseif isnumeric(init.IDs)
            init.IDs_cell{ii} = init.participant_id_trans(init.IDs(ii));
        else
            assert( iscell(init.IDs) || isnumeric(init.IDs),'init.IDs should be a numeric array or a cell array' )
        end
    end

    init.IDs = init.IDs_cell;
end


%read instructions into cell 
if isfield(init, 'instructions_txt')
    input.InstructionsC = read_txt(init.instructions_txt);
    if length(input.InstructionsC) > 1
        input.InstructionsC = {[input.InstructionsC{:}]};
    end
end

%variables that are changed in the loop in certain cases
init.write_events = true;
init.write_channels = true;

if isfield(init,'sub') && isfield(init,'sub_files')
    input.sub = init.sub;
    input.bdf_file_names = init.sub_files;
    
    if isstruct(init.sub)
        input.ses = fields(init.sub);
    else
        input.ses = 'None';
    end
    
elseif isfield(init,'data_dir')
    %define sessions, subjects and their data_files (in this case the data_files are bdf files)
    %varargin is the arguments that was parsed to this script, e.i. bids_dir and potentially single subject id and session
    [input.sub,input.ses,input.bdf_file_names,input.bdf_file_folders] = define_sub_ses_bdf(init);
else
    assert(isfield(init,'data_dir')~=1,'please specify either data_dir or sub and sub_files to init struct')
end

%get subjects with the additional files that was specified in the variable "must_exist_files"
if isfield(init,'must_exist_files')
    [input.subs_with_all_files, input.subs_with_additional_files, additional_file_names] = search_must_exist_files(init.data_dir, init.IDs, init.must_exist_files, init.must_exist_files_id_search, init.id_from_folder);
    cmp_and_print_subs_with_file(input.sub, input.subs_with_additional_files, init.must_exist_files, input.ses) % compare the subjects to be moved to the bids_dir with the subjects that has the additional files. This function also prints the comparison.
end

%prellocate memory for information about which sessions should be run
finished_ses = false(1,length(input.ses));
ses_run = false(1,length(input.ses));
ses_add = false(1,length(input.ses));

for s = 1:length(input.ses)
    %only include subjects that has the additional_files
    if isfield(init,'must_exist_files')%exist('must_exist_files','var')
        input.excluded_subs = input.sub.(input.ses{s})(~ismember(input.sub.(input.ses{s}),input.subs_with_all_files.(input.ses{s}))); %subjects which does not have one of the must_exist_files

        %print warning if subjects are excluded
        if ~isempty(input.excluded_subs)
            fprintf('WARNING: Subject %s will not be included in the BIDS directory as they are missing a "must_exist_file" ',input.excluded_subs{:})
            fprintf('WARNING: in session %s\n',input.ses{s})
            input.bdf_file_names.(input.ses{s}) = input.bdf_file_names.(input.ses{s})(~ismember(input.sub.(input.ses{s}),input.subs_with_all_files.(input.ses{s}))); %the exlusion of subjects which are already existing in the bids_dir
            input.sub.(input.ses{s}) = input.sub.(input.ses{s})(~ismember(input.sub.(input.ses{s}),input.subs_with_all_files.(input.ses{s}))); %the exlusion of the subjects who does not have the must_exist_files
        end
    end
    
    %find existing subjects in the bids structure by searching for files_checked
    input.existing_sub = find_existing_subs(init, input.ses(s));
    
    if length(init.varargin)==1 %if only the bids_dir is parsed to this function, e.i. running this script for multiple subjects 
        input.bdf_file_names.(input.ses{s}) = input.bdf_file_names.(input.ses{s})(~ismember(input.sub.(input.ses{s}),input.existing_sub.(input.ses{s}))); %the exlusion of subjects which are already existing in the bids_dir
        input.sub.(input.ses{s}) = input.sub.(input.ses{s})(~ismember(input.sub.(input.ses{s}),input.existing_sub.(input.ses{s}))); %the exlusion of subjects which are already existing in the bids_dir
        
        finished_ses(s) = isempty(input.sub.(input.ses{s})) && ~isempty(input.existing_sub.(input.ses{s})); %the sessions that are done
        ses_run(s) = ~isempty(input.sub.(input.ses{s})) && isempty(input.existing_sub.(input.ses{s})); %the sessions that should be run/started/created
        ses_add(s) = ~isempty(input.sub.(input.ses{s})) && ~isempty(input.existing_sub.(input.ses{s})); %the existing sessions with subjects to be added to
        
    elseif length(init.varargin)>1 %running this script for a single subject

        assert(~isempty(input.sub.(input.ses{s})),sprintf('A BIDS directory will not be made for subject %s. Check warnings above',init.varargin{2}))
        
        finished_ses(s) = false; %the sessions that are done
        ses_run(s) = ~isempty(input.sub.(input.ses{s})) && isempty(input.existing_sub.(input.ses{s})); %the sessions that should be run/started/created
        ses_add(s) = ~isempty(input.sub.(input.ses{s})) && ~isempty(input.existing_sub.(input.ses{s})); %the existing sessions with subjects to be added to
    end
end


%only run this script if there are unfinished sessions
assert( ~all(finished_ses), 'All relevant subject files are already moved to BIDS data structure in all sessions. Add more subject files to the data_dir or run EEG2BIDS.sh for a specific subject.')

%new sessions to be added (which also includes creating a new bids dataset)
input.run_mode = 'exist_BIDS';
if any(ses_run)
    if length(input.ses(ses_run))==1
        if strcmp(input.ses{ses_run},'None')
            fprintf('Creating new BIDS dataset from subject files \n')
        end
    else
        fprintf('Creating new BIDS dataset for session %s from subject files \n',input.ses{ses_run})
    end
    
    input.run_mode = 'new_BIDS';
else
    input.run_mode = 'exist_BIDS';
end

if isfile(fullfile(init.bids_dir,'participants.json')) % also check that participants json is written, as it is the last file written in the script 
    input.run_mode = 'exist_BIDS';
else
    input.run_mode = 'new_BIDS'; %implies that a new session or BIDS dataset is to be created, along general files such as dataset_description, participants.json
end

%subjects to be added to an existing session
if any(ses_add) %sessions to add assuming that other parts of the BIDS dataset have been created successfully
    ses_to_add = input.ses(ses_add);
    for s = 1:length(ses_to_add)
        for ss = 1:length(input.sub.(ses_to_add{s}))
            fprintf('Moving subject %s files into BIDS dataset for session %s \n',input.sub.(ses_to_add{s}){ss},ses_to_add{s})
        end
    end
end

%Copy the stimulation files to /stim direcotry
if isfield(init,'stim_files')
    
    stim_dir = fullfile(init.bids_dir,'/stimuli'); %the stimuli dir in the bids_dir
    if not(isfolder(stim_dir)) %only make the stimuli dir if it does not exist
        mkdir(stim_dir)
    end
    
    %get path to stim files in bids_dir and the name + extension of files
    [bids_stim_file_path, input.bids_stim_file_name] = get_bids_stim_files(init.stim_files,stim_dir);

    %copy them into the appropriate folder
    
    cp_ses_files(init.stim_files, bids_stim_file_path)    

end

%exlude extra subjects manually specified
if isfield(init,'exclude')
    input.sub.(input.ses{s}) = input.sub.(input.ses{s})(~ismember(input.sub.(input.ses{s}),init.exclude.(input.ses{s})));
end



input.init = init;


end

