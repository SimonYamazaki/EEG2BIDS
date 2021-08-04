function txt_C = read_txt(txt_file_path)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

fid = fopen(fullfile(txt_file_path), 'r');
if fid == -1
    assert(fid~=-1,sprintf('Could not open %s',txt_file_path))
end
txtC = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
txt_C  = txtC{1};
fclose(fid);

end

