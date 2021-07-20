addpath('/home/simonyj/EEG_flanker/fieldtrip/')
addpath('/home/simonyj/EEG_flanker/fieldtrip/fileio/')

%% Setup

data_dir = '/home/simonyj/EEG_flanker';
bids_dir = '/home/simonyj/EEG_BIDS';
name_of_files = 'flanker_kids_eegBackup_new-%s-1.edat2';

sourcedata_dir = fullfile(bids_dir,'/sourcedata');
if not(isfolder(sourcedata_dir))
    mkdir(sourcedata_dir)
end

% extract file names and subject ids 
file_struct = dir(sprintf('%s/*.edat2',data_dir));
file_names = cellstr({file_struct.name});
sub = cellfun(@(x) x(end-10:end-8),file_names,'un',0);

%find already existing subs by subject folders
sub_dirs = dir(sprintf('%s/sub-*',sourcedata_dir));
file_dirs = cellstr({sub_dirs.name});
existing_sub = cellfun(@(x) x(end-2:end),file_dirs,'un',0);

%check that the subjects with existing sub folders have the needed files 
files_ext_checked = {'.edat2'};
for f = 1:length(files_ext_checked)
    sub_dirs = dir(sprintf('%s/sourcedata/sub-*/ses-*/*/*%s',bids_dir,files_ext_checked{f}));
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
    fprintf('Creating new BIDS sourcedata directory with subject sourcedata files \n')
    run_mode = 'new_BIDS';
else
    fprintf('Moving subject %s files into BIDS sourcedatadata directory \n',sub{:})
    run_mode = 'add_sub';
end


%% Move eprime data into /sourcedata directory


for subindx=1:numel(sub)
    for sesindx=1:numel(ses)
        
    % initialize config struct
    cfg = [];
    cfg.method    = 'copy';
    cfg.datatype  = 'events';
    cfg.non_raw_data = true;
    
    % specify the output directory
    cfg.bidsroot  = sourcedata_dir;
    cfg.ses       = ses{sesindx};
    % get subject via ID 
    cfg.sub       = sub{subindx};
    sub_int       = str2num(cfg.sub);

    % define datafile for current subject
    cfg.dataset   = fullfile(data_dir,sprintf(name_of_files,cfg.sub));
    
    data2bids(cfg)
    
    end
end

% remove files not needed in the sourcedata directory
sfile_names = cellstr({ dir(fullfile(sourcedata_dir, '**/*_scans.tsv')).name });
sfile_dirs = cellstr({ dir(fullfile(sourcedata_dir, '**/*_scans.tsv')).folder });
sfiles2del = strcat(sfile_dirs,'/',sfile_names);
sfiles2del{end+1} = fullfile(sourcedata_dir, '/participants.tsv');
sfiles2del{end+1} = fullfile(sourcedata_dir, '/dataset_description.json');

for f = 1:length(sfiles2del)
    delete(sfiles2del{f})
end


if strcmp(run_mode,'new_BIDS')
    %write a readme about the e-prime data 
    fileID = fopen(fullfile(sourcedata_dir,'README.txt'),'w');
    fprintf(fileID,'E-prime behavioural sourcedata aqcuired for the flanker task');
    fclose(fileID);
end

%% Copy this script to the /code directory in BIDS structure 

code_dir = fullfile(sourcedata_dir,'/code');

if not(isfolder(code_dir))
    mkdir(code_dir)
end

file_path = mfilename('fullpath');
[ff,name,ext] = fileparts(file_path);
copyfile(strcat(file_path,'.m'), fullfile(code_dir,strcat(name,'.m')), 'f')


