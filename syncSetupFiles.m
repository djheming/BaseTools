function syncSetupFiles()

    % BaseTools.syncSetupFiles - Pushes the 'master' setup.m to all projects.
    
    % 1. Define the Master (The source of truth)
    masterPath = fullfile(fileparts(mfilename('fullpath')), 'setup.m');
    if ~exist(masterPath, 'file')
        error('Master setup.m not found!'); 
    end
    
    % 2. Define the Mapping: Root -> Pattern(s) to search
    % This structure clearly documents the lab's organization rules.
    homeDir = char(java.lang.System.getProperty('user.home'));
    mapping = {
        fullfile(homeDir, 'Documents', 'GitHub'),   '*/setup.m' ;
        fullfile(homeDir, 'Documents', 'Research'), '*/Matlab/setup.m'
    };

    % 3. Start the sync process
    fprintf('>>> Syncing Master setup.m to projects...\n');
    updateCount = 0;
    for i = 1:size(mapping, 1)

        searchRoot = mapping{i, 1};
        pattern    = mapping{i, 2};
        
        if ~isfolder(searchRoot)
            continue; 
        end
        
        % Find existing setup.m files matching the pattern
        items = dir(fullfile(searchRoot, pattern));
        for j = 1:numel(items)

            dest = fullfile(items(j).folder, items(j).name);
            
            % Skip if this IS the master file
            if strcmp(dest, masterPath)
                continue; 
            end
            
            % Otherwise, try overwriting this out-of-date setup.m file.
            try
                copyfile(masterPath, dest, 'f');
                fprintf('  [Updated] %s\n', dest);
                updateCount = updateCount + 1;
            catch
                warning('  [Failed]  %s', dest);
            end

        end

    end
    fprintf('Sync complete. %d files updated.\n', updateCount);

end