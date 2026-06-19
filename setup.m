function setup()

    % Hemingway Lab Universal Smart Setup.
    % Bootstraps the environment via recursive dependency discovery.
    
    root = fileparts(mfilename('fullpath'));
    
    % 1. Add this project's root to the path immediately
    addPathClean(root);
    
    % 2. Recursively discover and add dependencies
    fprintf('Starting recursive setup for: %s\n', root);
    [allLibPaths, foundNames] = collectDependencies(root, {}, {});
    
    for i = 1:numel(allLibPaths)
        addPathClean(allLibPaths{i});
        fprintf('  [Linked] %s\n', foundNames{i});
    end
    
    if numel(allLibPaths) > 0
        fprintf('Setup complete. %d libraries linked.\n', numel(allLibPaths));
    else
        fprintf('Setup complete. No external dependencies found.\n');
    end

end

%% INTERNAL HELPER FUNCTIONS (Self-Contained)

function [paths, names] = collectDependencies(currentFolder, paths, names)

    % Recursive crawler that handles Sibling, Libs, and Custom paths
    manifest = fullfile(currentFolder, 'dependencies.m');
    if ~exist(manifest, 'file')
        return; 
    end
    
    % Get dependencies from the manifest
    currDir = pwd;
    cleanup = onCleanup(@() cd(currDir));
    cd(currentFolder);
    deps = dependencies();
    clear cleanup; % Trigger cd back to currDir
    
    for i = 1:numel(deps)

        libName = deps{i};
        if ismember(libName, names)
            continue;  % Avoid loops
        end
        
        target = findLibrary(currentFolder, libName);
        
        if ~isempty(target) && isfolder(target)
            paths{end+1} = target; %#ok<AGROW>
            names{end+1} = libName; %#ok<AGROW>
            [paths, names] = collectDependencies(target, paths, names); % Recurse
        else
            warning('Setup:MissingDependency', 'Could not find dependency: %s', libName);
        end

    end

end

function target = findLibrary(sourceRoot, libName)

    % Priority 1: Local /libs (Archive/Bundle Mode)
    path1 = fullfile(sourceRoot, 'libs', libName);
    % Priority 2: Sibling Directory (Development Mode)
    path2 = fullfile(fileparts(sourceRoot), libName);
    % Priority 3: Check git-ignored local_paths.m
    [ path3, labRoot ] = checkLocalConfig(libName);
    if ~isempty( labRoot )
        path4 = fullfile(labRoot, libName);
    else
        path4 = '';
    end
    
    % Waterfall through the paths in priority order
    if isfolder(path1)
        target = path1;
    elseif isfolder(path2)
        target = path2;
    elseif ~isempty(path3) && isfolder(path3)
        target = path3;
    elseif ~isempty(path4) && isfolder(path4)
        target = path4;
    else
        % Priority 5: Interactive Prompt
        target = promptForPath(libName);
    end
end

function [ p, labRoot ] = checkLocalConfig(libName)
    p = '';
    labRoot = '';
    if exist('local_paths.m', 'file')
        config = local_paths();
        if isfield(config, libName)
            p = config.(libName); 
        end
        if isfield(config, 'LabRoot')
            labRoot = config.LabRoot; 
        end
    end
end

function target = promptForPath(libName)

    target = '';
    % If no UI is available (e.g., server), we can't prompt
    if ~usejava('desktop')
        return; 
    end
    
    fprintf('  [?] Dependency "%s" not found in siblings or /libs.\n', libName);
    sel = uigetdir(pwd, sprintf('Select folder for library: %s', libName));
    
    if sel ~= 0
        target = sel;
        parentDir = fileparts(target);
        % Ask whether user wants us to remember this parent folder as the
        % labRoot folder.
        choice = questdlg(sprintf('Would you like to remember this folder (%s) as the Lab Root?\n', parentDir), 'Set Lab Root', 'Yes', 'No', 'Yes');
         if strcmp(choice, 'Yes')
             saveLocalPath('LabRoot', parentDir);
         else
             saveLocalPath(libName, target);
         end
    end

end

function saveLocalPath(libName, targetPath)

    fname = 'local_paths.m';
    if ~exist(fname, 'file')
        fid = fopen(fname, 'w');
        fprintf(fid, 'function p = local_paths()\n\np = struct();\n');
        fclose(fid);
    end
    % Append choice to the file
    fid = fopen(fname, 'a');
    fprintf(fid, 'p.%s = ''%s'';\n', libName, targetPath);
    fclose(fid);
    fprintf('  [Saved] Path to %s saved in local_paths.m\n', libName);

end

function addPathClean(pathIn)

    % genpath + filtering .git and other hidden metadata
    p = genpath(pathIn);
    parts = strsplit(p, pathsep);
    % Exclude hidden folders like .git, .DS_Store, etc.
    keep = cellfun(@(x) ~isempty(x) && ~contains(x, [filesep '.']), parts);
    validParts = parts(keep);
    if ~isempty(validParts)
        addpath(strjoin(validParts, pathsep));
    end

end