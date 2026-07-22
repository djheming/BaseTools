function setup()

    % Hemingway Lab Universal Smart Setup.
    % Bootstraps the environment via recursive dependency discovery.

    % Start clearn.
    restoredefaultpath;
    
    % Take note of our starting point.
    root = fileparts(mfilename('fullpath'));
    
    % 1. Add this project's root to the path immediately
    addPathClean(root);
    
    % 2. Recursively discover and add dependencies
    fprintf('Starting recursive setup for: %s\n', root);
    [allLibPaths, foundNames, foundStrategies] = collectDependencies(root, {}, {}, {});
    
    for i = 1:numel(allLibPaths)
        addPathClean(allLibPaths{i});
        fprintf('  [Linked] %-15s [via %s]\n', foundNames{i}, foundStrategies{i});
    end
    
    if numel(allLibPaths) > 0
        fprintf('Setup complete. %d libraries linked.\n', numel(allLibPaths));
    else
        fprintf('Setup complete. No external dependencies found.\n');
    end

end

%% INTERNAL HELPER FUNCTIONS (Self-Contained)

function [paths, names, strategies] = collectDependencies(currentFolder, paths, names, strategies)

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
        
        [target, strategy] = findLibrary(currentFolder, libName);
        
        if ~isempty(target) && isfolder(target)
            paths{end+1} = target; %#ok<AGROW>
            names{end+1} = libName; %#ok<AGROW>
            strategies{end+1} = strategy; %#ok<AGROW>
            [paths, names, strategies] = collectDependencies(target, paths, names, strategies); % Recurse
        else
            warning('Setup:MissingDependency', 'Could not find dependency: %s', libName);
        end

    end

end

function [target, strategy] = findLibrary(sourceRoot, libName)

    strategy = 'NotFound';

    % Priority 1: Local /libs (Archive/Bundle Mode)
    path1 = fullfile(sourceRoot, 'libs', libName);
    % Priority 2: Sibling Directory (Development Mode)
    path2 = fullfile(fileparts(sourceRoot), libName);
    % Priority 3 & 4: Check git-ignored local_paths.m
    [ path3, labRoot ] = checkLocalConfig(libName);

    % Priority 5: Environment Variable (Remote/Batch Mode)
    envRoot = getenv('HEMINGWAY_LAB_ROOT');    
    
    % Waterfall through the paths in priority order
    if isfolder(path1)
        target = path1;
        strategy = 'bundle: /libs';
    elseif isfolder(path2)
        target = path2;
        strategy = 'sibling folder';
    elseif ~isempty(path3) && isfolder(path3)
        target = path3;
        strategy = 'local_paths.m (direct)';
    elseif ~isempty(labRoot) && isfolder(fullfile(labRoot, libName))
        % Priority 4: checkLocalConfig returned a valid labRoot folder
        target = fullfile(labRoot, libName);
        strategy = 'local_paths.m (LabRoot)';
    elseif ~isempty(envRoot) && isfolder(fullfile(envRoot, libName))
        % Priority 5: checkLocalConfig doesn't know the labRoot but maybe
        % it has been specified via an environment variable?
        target = fullfile(envRoot, libName);
        strategy = 'Env Var (HEMINGWAY_LAB_ROOT)';
    else
        % Priority 6: Interactive Prompt
        target = promptForPath(libName);
        if ~isempty(target)
            strategy = 'user selection';
        end
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

    % Check whether in batch mode where the code is being run remotely
    % without an interactive GUI. 
    isBatch = batchStartupOptionUsed || ~usejava('desktop');
    if isBatch
        error('Setup:MissingDependency', 'Dependency "%s" not found and no UI available for prompting. Check HEMINGWAY_LAB_ROOT.', libName);
    end

    % If we get this far, we have a GUI available to prompt the user.
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