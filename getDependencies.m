function [paths, names, strategies] = getDependencies(currentFolder, paths, names, strategies)

    % getDependencies - Recursively discovers library dependencies.
    % 
    % This function uses the "Waterfall Strategy" to find libraries, ensuring
    % that the discovery logic is identical to that used in setup.m.

    if nargin < 2
        paths = {}; 
    end
    if nargin < 3
        names = {}; 
    end
    if nargin < 4
        strategies = {};
    end

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
            
            % Recurse
            [paths, names, strategies] = getDependencies(target, paths, names, strategies); 
        else
            warning('getDependencies:MissingDependency', 'Could not find dependency: %s', libName);
        end

    end

end

%% INTERNAL HELPER FUNCTIONS (Identical to setup.m)

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

    % Priority 6: In case one is not specified, we'll define a "standard"
    % or "best guess" about the location of the lab root. If the user does
    % not follow this convention, we go to the last resort (Priority 7) of
    % prompting them to browse.
    homeDir = char(java.lang.System.getProperty('user.home'));
    standardRoot = fullfile(homeDir, 'Documents', 'GitHub');
    pathStandard = fullfile(standardRoot, libName);
    
    % Waterfall through the paths in priority order
    if isfolder(path1)
        % Priority 1: If there's a /libs folder, that takes priority.
        target = path1;
        strategy = 'bundle: /libs';
    elseif isfolder(path2)
        % Priority 2: Developers will often be working in a repo folder
        % that is a sibling of all the other library repos.
        target = path2;
        strategy = 'sibling folder';
    elseif ~isempty(path3) && isfolder(path3)
        % Priority 3: Neither of the above two situations apply but perhaps
        % the user has deliberately specified and recorded a preferred path
        % in the local_paths.m file (this usually comes from having
        % previously failed all the way down to Priority 7).
        target = path3;
        strategy = 'local_paths.m (direct)';
    elseif ~isempty(labRoot) && isfolder(fullfile(labRoot, libName))
        % Priority 4: checkLocalConfig returned a valid labRoot folder.
        target = fullfile(labRoot, libName);
        strategy = 'local_paths.m (LabRoot)';
    elseif ~isempty(envRoot) && isfolder(fullfile(envRoot, libName))
        % Priority 5: checkLocalConfig doesn't know the labRoot but maybe
        % it has been specified via an environment variable?
        target = fullfile(envRoot, libName);
        strategy = 'Env Var (HEMINGWAY_LAB_ROOT)';
    elseif isfolder(pathStandard)
        % Priority 6: Best guess of a conventional location.
        target = pathStandard;
        strategy = 'Standard Convention (~/Documents/GitHub)';        
    else
        % Priority 7: Interactive prompt (last resort).
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
        try
            config = local_paths();
            if isfield(config, libName)
                p = config.(libName); 
            end
            if isfield(config, 'LabRoot')
                labRoot = config.LabRoot; 
            end
        catch
            % We catch errors here in case local_paths.m has a typo
            % or is otherwise malformed, allowing the waterfall to proceed.
        end
    end
end

function target = promptForPath(libName)

    target = '';

    % Check whether in batch mode where the code is being run remotely
    % without an interactive GUI. 
    isBatch = batchStartupOptionUsed || ~usejava('desktop');
    if isBatch
        error('getDependencies:MissingDependency', 'Dependency "%s" not found and no UI available for prompting. Check HEMINGWAY_LAB_ROOT.', libName);
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