function projectRoot = startup_project()
%STARTUP_PROJECT Add project folders and create output directories.
projectRoot = fileparts(mfilename('fullpath'));
allPaths = string(strsplit(genpath(projectRoot),pathsep));
reject = contains(allPaths,filesep+"results");
addpath(char(strjoin(allPaths(~reject & strlength(allPaths)>0),pathsep)));
folders = {"results/raw","results/tables","results/figures", ...
    "results/reports","results/logs","results/temp"};
for k = 1:numel(folders)
    folder = fullfile(projectRoot,folders{k});
    if ~isfolder(folder), mkdir(folder); end
end
end
