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
                    args.(argarray{i}) = argarray{i+1};
                end
            end
        end
        function argarray = struct2argarray( args )
            names = fieldnames( args );
            argarray = cell( 1, 2*length(names) );
            for i = 1 : length(names)
                argarray{2*i-1} = names{i};
                argarray{2*i} = args.(names{i});
            end
        end
        
        % Obtain a set of basic Markers for plotting.
        function MarkerSet = get_marker_set( N )
            MarkerSet = 'so^*dpvx><+.';
            MarkerSet = repmat( MarkerSet, 1, ceil(N/length(MarkerSet)) );
            MarkerSet = MarkerSet(1:N);
        end
        
        % Report on how long something took.
        function str = timetostr( t_elapsed )
            if t_elapsed < 60
                t_report = t_elapsed;
                t_units = 'seconds';
            elseif t_elapsed < BaseTools.sperhr
                t_report = t_elapsed/60;
                t_units = 'minutes';
            elseif t_elapsed < BaseTools.sperday
                t_report = t_elapsed/(BaseTools.sperhr);
                t_units = 'hours';
            elseif t_elapsed < BaseTools.speryr
                t_report = t_elapsed/(BaseTools.sperday);
                t_units = 'days';
            elseif t_elapsed < BaseTools.speryr * 1e3
                t_report = t_elapsed/(BaseTools.speryr);
                t_units = 'years';
            elseif t_elapsed < BaseTools.speryr * 1e6
                t_report = t_elapsed/(BaseTools.speryr*1e3);
                t_units = 'kyrs';
            elseif t_elapsed < BaseTools.speryr * 1e9
                t_report = t_elapsed/(BaseTools.speryr*1e6);
                t_units = 'Myrs';
            else
                t_report = t_elapsed/(BaseTools.speryr*1e9);
                t_units = 'Gyrs';
            end
            str = sprintf( '%.1f %s', t_report, t_units );
        end
        function progress_report( timername, k, N )
            % Since <timername> timer was started, we have completed k of N
            % steps. How are we doing and when will we be done? 
            t_elapsed = toc(timername);
            dt = (t_elapsed/k);
            if t_elapsed < 90 % For the first 1.5 minutes.
                interval = 10; % Every ten seconds.
            elseif t_elapsed < 300 % For the first 5 minutes.
                interval = 30; % Every 30 seconds.
            else
                interval = 300; % Every five minutes.
            end
            if t_elapsed > 5 && ( mod(k,round(interval/dt)) == 0 )
                rt = dt*(N-k);
                etc = now + datenum(0,0,0,0,0,rt);
                fprintf( 'Completed %d/%d=%.1f%% in %s (%s each; ETC: %s).\n', k, N, 100*k/N, BaseTools.timetostr(t_elapsed), BaseTools.timetostr(dt), datestr(etc,13) );
            end
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

