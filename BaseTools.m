classdef BaseTools

    % BaseTools: class for holding a set of commonly used tools that don't
    % belong exclusively to any particular class.
    %
    %   Disclaimer: This code was not developed for commercial purposes and has
    %   not been subjected to formal validation testing. I find it useful for
    %   my own work, and I hope you will too, but I make no guarantees as to
    %   the accuracy or robustness of this code.
    %
    %   Doug Hemingway (douglas.hemingway@gmail.com)
    %   Carnegie Institution for Science
    %   2019-01-13
    %    
    
    properties (Constant)
        G = 6.67408e-11; % Source: http://arxiv.org/pdf/1507.07956v1.pdf, 2016-03-14
        speryr = 3600 * 8766; % seconds per year
        sperday = 86400; % seconds per day
        sperhr = 3600; % seconds per hour
        Rg = 8.31446261815324; % J/mol/K, Gas constant
        AU = 149.598023e9; % Astronomical Unit (meters)
    end
    
    methods (Static)

        % Parsing of name/value pair arguments into a handy structure.
        function args = argarray2struct( argarray )
            args = [];
            for i = 1 : 2 : length(argarray)-1
                if ~isempty( argarray{i} )
                    eval( [ 'args.' argarray{i} ' = argarray{i+1};' ] );
                end
            end
        end
        
        % Obtain a set of basic Markers for plotting.
        function MarkerSet = get_marker_set( N )
            MarkerSet = 'so^*dpvx><+.';
            MarkerSet = repmat( MarkerSet, 1, ceil(N/length(MarkerSet)) );
            MarkerSet = MarkerSet(1:N);
        end
        
        % Obtain a sequence with nice round steps.
        function steps = get_round_step_size( vals, target_N )
            
            vmin = min(vals(:));
            vmax = max(vals(:));
            vwidth = vmax - vmin;
            if vwidth == 0
                steps = vmin;
            else
                ideal_step = vwidth/target_N;
                oom = floor( log10(ideal_step) );
                candidate_steps = [ 1 2 2.5 5 10 20 50 100 ]*10^oom;
                best = find( vwidth./candidate_steps <= target_N, 1, 'first' );
                step_size = candidate_steps(best);
                if vmin > 0 && vmax > 0
                    steps = ( 0 : step_size : vmax )';
                    steps = steps( steps > vmin );
                elseif vmin <= 0 && vmax >= 0
                    psteps = ( 0 : step_size : vmax )';
                    nsteps = flip( ( 0 : -step_size : vmin )', 1 );
                    steps = unique( [ nsteps; psteps ] );
                elseif vmin < 0 && vmax < 0
                    steps = flip( ( 0 : -step_size : vmin )', 1 );
                    steps = steps( steps < vmax );
                end
            end
            
        end
        
    end
end

