addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')

%% Setup

data_dir = '/home/simonyj/EEG_flanker';
bids_dir = '/home/simonyj/EEG_BIDS';
name_of_files = {'/0%s_data.mat', '/0%s_info.mat'};

derivative_dir = fullfile(bids_dir,'/derivatives/pipeline1');
deriv_code_dir = fullfile(derivative_dir,'/code');

if not(isfolder(deriv_code_dir))
    mkdir(deriv_code_dir)
end

% extract file names and subject ids 
file_struct = dir(sprintf('%s/*_data.mat',data_dir));
file_names = cellstr({file_struct.name});
sub = cellfun(@(x) x(2:4),file_names,'un',0);

%find already existing subs by subject folders
sub_dirs = dir(sprintf('%s/sub-*',derivative_dir));
file_dirs = cellstr({sub_dirs.name});
existing_sub = cellfun(@(x) x(end-2:end),file_dirs,'un',0);

%check that the subjects with existing sub folders have the needed files 
files_checked = {'eeg_deriv.mat','beh_info.mat'};
for f = 1:length(files_checked)
    sub_dirs = dir(sprintf('%s/sub-*/ses-*/*/*_%s',derivative_dir,files_checked{f}));
    file_dirs = {sub_dirs.name};
    subs_with_file = cellfun(@(x) x(5:7),file_dirs,'un',0);
    if any(~ismember(existing_sub,subs_with_file))
        sub2redo = existing_sub{~ismember(existing_sub,subs_with_file)};
        existing_sub(strcmp(existing_sub,sub2redo))=[];
        fprintf('Subject %s have missing BIDS files \n',sub2redo)
    end
end
sub = sub(~ismember(sub,existing_sub));


if isempty(sub) && ~isempty(existing_sub)
    assert(~isempty(sub),'All relevant subject files are moved to BIDS data structure. Add more subject files to the data_dir.')
elseif ~isempty(sub) && isempty(existing_sub)
    fprintf('Creating new BIDS derivative directory with subject derivative files \n')
    run_mode = 'new_BIDS';
else
    fprintf('Moving subject %s files into BIDS derivative directory \n',sub{:})
    run_mode = 'add_sub';
end



%% Generate the BIDS structure


for subindx=1:numel(sub)
    for sesindx=1:1%numel(ses)
        
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy';
    cfg.datatype  = 'eeg_deriv';
    cfg.non_raw_data = true;
    
    % specify the output directory
    cfg.bidsroot  = derivative_dir;
    cfg.ses       = ses{sesindx};
    % get subject via ID 
    cfg.sub       = sub{subindx};
    sub_int       = str2num(cfg.sub);

    % define datafile for current subject
    cfg.dataset   = fullfile(data_dir,sprintf(name_of_files{1},cfg.sub));
    data2bids(cfg)

    filename = fullfile(derivative_dir, sprintf('/sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-Flanker_%s.json',cfg.sub,cfg.ses,cfg.sub,cfg.ses,cfg.datatype));
    cfg.DerivativeDescriptionEEG.Description = 'Preprocessed using the fieldtrip toolbox, where only correct congruent and incongruent trials were used. Assumed to be produced by FlankerEEG_file2_preprocess.m being run for each subject.';
    cfg.DerivativeDescriptionEEG.Sources = {'../../Beh4EEG_inclnew.mat',sprintf('../../sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-Flanker_eeg.bdf',cfg.sub,cfg.ses,cfg.sub,cfg.ses)};
    fn = fieldnames(cfg.DerivativeDescriptionEEG);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    DerivativeDescriptionEEG_settings = keepfields(cfg.DerivativeDescriptionEEG, fn);
    ft_write_json(filename, DerivativeDescriptionEEG_settings);

    
    cfg.dataset   = fullfile(data_dir,sprintf(name_of_files{2},cfg.sub));
    cfg.datatype  = 'beh_info';
    data2bids(cfg)
    
    filename = fullfile(derivative_dir, sprintf('/sub-%s/ses-%s/beh/sub-%s_ses-%s_task-Flanker_%s.json',cfg.sub,cfg.ses,cfg.sub,cfg.ses,cfg.datatype));
    cfg.DerivativeDescriptionBehav.Description = 'Preprocessed using the fieldtrip toolbox, where only correct congruent and incongruent trials were used. Assumed to be produced by FlankerEEG_file2_preprocess.m being run for each subject.';
    cfg.DerivativeDescriptionBehav.Sources = {'../../Beh4EEG_inclnew.mat',sprintf('../../sub-%s/ses-%s/eeg/sub-%s_ses-%s_task-Flanker_eeg.bdf',cfg.sub,cfg.ses,cfg.sub,cfg.ses)};
    fn = fieldnames(cfg.DerivativeDescriptionBehav);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    DerivativeDescriptionBehav_settings = keepfields(cfg.DerivativeDescriptionBehav, fn);
    ft_write_json(filename, DerivativeDescriptionBehav_settings);
    
    end
end

%% Make derivative dataset_description.json file 

if strcmp(run_mode,'new_BIDS')
    
    filename = fullfile(derivative_dir, 'dataset_description.json');

    cfg.DerivativeDescription.Name = 'preprocessed EEG and behavioural data';
    cfg.DerivativeDescription.BIDSVersion = '1.2';
    cfg.DerivativeDescription.DatasetType = 'derivative';

    cfg.DerivativeDescription.GeneratedBy.Name = 'pipeline1';
    cfg.DerivativeDescription.GeneratedBy.Version = '1.0';
    cfg.DerivativeDescription.GeneratedBy.Description = 'Preprocessed using the fieldtrip toolbox, where only correct congruent and incongruent trials were used. Assumed to be produced by FlankerEEG_file2_preprocess.m being run for each subject.';
    cfg.DerivativeDescription.GeneratedBy.CodeURL = 'Maybe make github repo?';

    fn = fieldnames(cfg.DerivativeDescription);
    fn = fn(~cellfun(@isempty, regexp(fn, '^[A-Z].*')));
    DerivativeDescription_settings = keepfields(cfg.DerivativeDescription, fn);
    ft_write_json(filename, DerivativeDescription_settings);


    % Move scripts used to produce derivative into code/ directory
    copyfile(fullfile(data_dir,'/FlankerEEG_file2_preprocess.m'), fullfile(deriv_code_dir,'/FlankerEEG_file2_preprocess.m'), 'f')

    %move behavioural data .mat file into root dir 
    copyfile(fullfile(data_dir,'/Beh4EEG_inclnew.mat'), fullfile(bids_dir,'/Beh4EEG_inclnew.mat'), 'f')

end


%% Copy this script to the /code directory in BIDS structure 

file_path = mfilename('fullpath');
[ff,name,ext] = fileparts(file_path);
copyfile(strcat(file_path,'.m'), fullfile(deriv_code_dir,strcat(name,'.m')), 'f')
