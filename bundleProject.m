function bundleProject(sourceRoot, destinationDir)

    % Create a self-contained distribution folder (Recursive).
    % Everything the project needs is physically copied into /libs.
    %
    % Usage: If you're inside the root of the project of interest:
    %   bundleProject( '.', 'path/to/release/folder' );
    
    
    % 1. Setup the destination
    sourceRoot = getAbsolutePath(sourceRoot);
    [~, projectName] = fileparts(sourceRoot);
    finalDest = fullfile(destinationDir, projectName);
    
    if exist(finalDest, 'dir')
        fprintf('  [Cleaning] Removing existing bundle at %s...\n', finalDest);
        rmdir(finalDest, 's'); 
    end
    mkdir(finalDest);
    
    % 2. Copy the main project files
    fprintf('  [Bundling] Project: %s\n', projectName);
    % We exclude the existing 'libs' folder from the source to prevent nesting.
    copyClean(sourceRoot, finalDest, {'libs'});
    
    % 3. Find dependencies (Recursive crawl)
    % Uses getDependencies.m which mirrors setup.m logic.
    [libPaths, libNames, libStrategies] = getDependencies(sourceRoot);
    
    % 4. Populate the /libs folder
    if ~isempty(libPaths)

        libsDir = fullfile(finalDest, 'libs');
        if ~exist(libsDir, 'dir')
            mkdir(libsDir); 
        end
        
        for i = 1:numel(libPaths)
            destPath = fullfile(libsDir, libNames{i});
            fprintf('  [Bundling] %-15s [via %s]\n', libNames{i}, libStrategies{i});
            copyClean(libPaths{i}, destPath);
        end

    end
    
    % 5. Master Setup Sync
    % We ensure that the setup.m in the bundle is the latest Master Setup logic.
    masterSetup = fullfile(fileparts(mfilename('fullpath')), 'setup.m');
    bundleSetup = fullfile(finalDest, 'setup.m');
    if exist(masterSetup, 'file') && exist(bundleSetup, 'file')
        copyfile(masterSetup, bundleSetup, 'f');
    end
    
    fprintf('\nBundle complete: %s\n', finalDest);

end

%% HELPER FUNCTIONS

function copyClean(source, dest, excludeNames)

    % Copies a folder while ignoring Git/OS metadata and specific excludes.
    if nargin < 3
        excludeNames = {};
    end
    
    if ~exist(dest, 'dir')
        mkdir(dest); 
    end
    
    items = dir(source);
    for i = 1:numel(items)
        name = items(i).name;
        
        % Skip dots
        if strcmp(name, '.') || strcmp(name, '..')
            continue;
        end
        
        % Ignore hidden files/folders (starting with .)
        if startsWith(name, '.')
            continue;
        end
        
        % Ignore explicitly excluded folder names
        if ismember(name, excludeNames)
            continue;
        end
        
        srcItem = fullfile(source, name);
        dstItem = fullfile(dest, name);
        
        if items(i).isdir
            % Recursive copy for directories
            copyClean(srcItem, dstItem, excludeNames);
        else
            % Direct copy for files
            copyfile(srcItem, dstItem, 'f');
        end
    end

end

function absPath = getAbsolutePath(inputPath)
    currDir = pwd;
    if ~exist(inputPath, 'dir')
        error('Source path does not exist: %s', inputPath);
    end
    cd(inputPath);
    absPath = pwd;
    cd(currDir);
end