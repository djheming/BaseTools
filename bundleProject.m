function bundleProject(sourceRoot, destinationDir)

    % Create a self-contained distribution folder (Recursive).
    % Everything the project needs is physically copied into /libs.
    
    % 1. Setup the destination
    % Resolve absolute path to avoid logic errors with '..'
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
    copyClean(sourceRoot, finalDest);
    
    % 3. Find dependencies (Recursive crawl)
    % Note: This uses the getDependencies helper found in BaseTools.
    [libPaths, libNames] = getDependencies(sourceRoot);
    
    % 4. Populate the /libs folder
    if ~isempty(libPaths)

        libsDir = fullfile(finalDest, 'libs');
        if ~exist(libsDir, 'dir')
            mkdir(libsDir); 
        end
        
        for i = 1:numel(libPaths)
            % Flattening: All dependencies go into one /libs folder
            destPath = fullfile(libsDir, libNames{i});
            fprintf('  [Bundling] Dependency: %s\n', libNames{i});
            copyClean(libPaths{i}, destPath);
        end

    end
    
    fprintf('\nBundle complete: %s\n', finalDest);

end

%% HELPER FUNCTIONS

function copyClean(source, dest)

    % Copies a folder and selectively removes Git/OS metadata
    if ~exist(dest, 'dir')
        mkdir(dest); 
    end
    
    % Copy everything first
    copyfile(source, dest);
    
    % 1. Find all .git entries
    % Using dir with '**' is thorough, but we must filter for directories
    items = dir(fullfile(dest, '**', '.git'));
    for i = 1:numel(items)
        itemPath = fullfile(items(i).folder, items(i).name);
        % Safety: Check it is a directory and still exists 
        % (Parent .git removal might have already nuked a nested .git)
        if items(i).isdir && exist(itemPath, 'dir')
            rmdir(itemPath, 's');
        elseif exist(itemPath, 'file')
            delete(itemPath);
        end
    end
    
    % 2. Clean up specific junk files (not directories)
    junkPatterns = {'.DS_Store', '.gitattributes', '.gitignore'};
    for j = 1:numel(junkPatterns)
        items = dir(fullfile(dest, '**', junkPatterns{j}));
        for i = 1:numel(items)
            itemPath = fullfile(items(i).folder, items(i).name);
            if exist(itemPath, 'file') && ~items(i).isdir
                delete(itemPath);
            end
        end
    end

end

function absPath = getAbsolutePath(inputPath)

    % Helper to resolve relative paths like '../' to absolute strings
    currDir = pwd;
    if ~exist(inputPath, 'dir')
        error('Source path does not exist: %s', inputPath);
    end
    cd(inputPath);
    absPath = pwd;
    cd(currDir);

end