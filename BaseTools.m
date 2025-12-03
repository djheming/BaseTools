classdef BaseTools

    % BaseTools: class for holding a set of commonly used tools that don't
    % belong exclusively to any particular class.
    %
    %   Disclaimer: This code is provided as-is, has been tested only very
    %   informally, and may not always behave as intended. I find it useful for
    %   my own work, and I hope you will too, but I make no guarantees as to
    %   the accuracy or robustness of this code. This code is also actively
    %   under development and future versions may not be backward compatible.
    %
    %   Doug Hemingway (dhemingway@carnegiescience.edu)
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
        function [ args, outarray ] = argarray2struct( argarray, defargs )
            
            % Build a structure from the input arguments. Assume the input
            % arguments are in name,value pairs but that there may also be
            % a few leading arguments that are not organized that way. Put
            % those leading arguments in an array.
            if ~exist('defargs', 'var')
                defargs = {};
            end

            % Look for where the name-value pairs begin. A name must be
            % followed by another agument and it must be a valid variable
            % name.
            isName = @(x) (ischar(x) || isstring(x)) && isvarname(x);
            Narg = numel(argarray);
            firstNV = [];
            for k = 1:Narg-1  % need at least 2 elements for a pair
                if isName(argarray{k})
                    firstNV = k;
                    break;
                end
            end

            % Assign positional arguments.
            if isempty(firstNV)
                % no NV pairs detected, everything positional
                args.posArgs = argarray;
                nvArgs = defargs;
            else
                args.posArgs = argarray(1:firstNV-1);
                nvArgs = [defargs argarray(firstNV:end)];
            end

            % Process name-value pairs into the output structure.
            N = numel(nvArgs);
            if mod(N,2) ~= 0
                error('Input must have an even number of input strings');
            end
            for i = 1:2:N-1
                if ~isempty(nvArgs{i}) && isvarname(nvArgs{i})
                    args.(nvArgs{i}) = nvArgs{i+1};
                end
            end

            % The user may also want a new argarray that corresponds to the
            % resulting args structure.
            outarray = BaseTools.struct2argarray(args);

        end
        function argarray = struct2argarray( args )
            if isfield( args, 'posArgs' )
                args = rmfield( args, 'posArgs' );
            end
            names = fieldnames( args );
            argarray = cell( 1, 2*length(names) );
            for i = 1 : length(names)
                argarray{2*i-1} = names{i};
                argarray{2*i} = args.(names{i});
            end
        end

        % Parse positional arguments and pull out axes handle (or make one
        % if it's not there).
        function [ ah, fh ] = extractAxesHandle( args )
            ah = [];
            for k = 1 : length(args.posArgs)
                if isa( args.posArgs{k}, 'matlab.graphics.axis.Axes' )
                    ah = args.posArgs{k};
                end
            end
            [ ah, fh ] = BaseTools.verify_axes_handle( ah );
        end

        % Make sure we have an active plotting axes.
        function [ ah, fh ] = verify_axes_handle( ah )
            if exist( 'ah', 'var' ) && isa( ah, 'matlab.graphics.axis.Axes' )
                fh = ah.Parent;
            else
                fh = figure;
                ah = axes('Parent',fh);
            end
        end

        % Exclude axes handles from a cell array.
        function non_axes = filter_out_axes( argarray )
            non_axes = argarray( ~cellfun(@(x) isa(x, 'matlab.graphics.axis.Axes'), argarray) );
        end

        % Parse contour matrix.
        function contours = parseContourMatrix(C)
            contours = struct('level', {}, 'x', {}, 'y', {});
            idx = 1;
            while idx < size(C, 2)
                level = C(1, idx);
                nPts = C(2, idx);
                ptsX = C(1, idx+1:idx+nPts);
                ptsY = C(2, idx+1:idx+nPts);
                contours(end+1) = struct('level', level, 'x', ptsX, 'y', ptsY); %#ok<AGROW>
                idx = idx + nPts + 1;
            end
        end
        
        % Basic conversion between lat/lon and theta/phi.
        function [ lat, lon ] = thetaphi2latlon( theta, phi )
            colat = theta*180/pi;
            lat = 90-colat;
            lon = phi*180/pi;
        end
        function [ theta, phi ] = latlon2thetaphi( lat, lon )
            colat = 90-lat;
            theta = colat*pi/180;
            phi = lon*pi/180;
        end

        % Spherical interpolation between vectors.
        function vq = interp_vectors( x, v, xq )
            % x and xq must be 1D arrays with xq defined somewhere between
            % the min and max of x. The input v should be a 3xN array
            % representing N distinct vectors, one corresponding to each x.
            % The output vectors are spherically interpolated.
            num_input_vecs = size(v,2);
            if length(x) ~= num_input_vecs
                error( 'v must have one column per element of x' );
            end
            num_output_vecs = length(xq);
            vq = nan(3,num_output_vecs);
            for i = 1 : num_input_vecs-1
                v1 = v(:,i);
                v2 = v(:,i+1);
                m1 = norm(v1);
                m2 = norm(v2);
                u1 = v1/m1;
                u2 = v2/m2;
                dotp = dot(u1,u2);
                dotp = max(min(dotp, 1), -1);  % Clamp to avoid NaNs due to floating point
                theta = acos(dotp);
                valinds = xq>=x(i) & xq<=x(i+1);
                xqi = xq( valinds );
                f = (xqi-x(i))/(x(i+1)-x(i));
                if theta > 0
                    u = ( u1 * sin((1-f)*theta) + u2 * sin(f*theta) )/sin(theta);
                    m = m1 * (1-f) + m2 * f;
                    vq(:,valinds) = u .* m;
                else
                    vq(:,valinds) = repmat( v1, 1, sum(valinds) );
                end
            end
        end

        % Smooth a path along a sphere without losing the large scale shape
        % of the path.
        function [ smooth_phis, smooth_thetas, smooth_sigmas ] = smoothShericalCoordinates( phis, thetas )
            % Force column vectors.
            phis = phis(:);
            thetas = thetas(:);
            % Convert (phi, theta) to Cartesian unit vectors
            % theta: colatitude (0 at North Pole), phi: longitude
            x = cos(phis) .* sin(thetas);
            y = sin(phis) .* sin(thetas);
            z = cos(thetas);
            % Smooth Cartesian components
            if length(z) > 30
                w = 11;
            else
                w = 5;
            end
            x_s = smoothdata( x, 'movmean', w );
            y_s = smoothdata( y, 'movmean', w );
            z_s = smoothdata( z, 'movmean', w );
            % Re-normalize to stay on the unit sphere
            r = sqrt(x_s.^2 + y_s.^2 + z_s.^2);
            x_s = x_s ./ r;
            y_s = y_s ./ r;
            z_s = z_s ./ r;
            % Convert back to spherical angles
            smooth_thetas = acos(z_s);              % theta in [0, pi]
            smooth_phis   = atan2(y_s, x_s);        % phi in [-pi, pi]
            smooth_sigmas = BaseTools.getCumArcLength( smooth_phis, smooth_thetas );
        end
        function [ lattxt, lontxt ] = latlon2txt( lat, lon, N )
            if ~exist( 'N', 'var' ) || isempty( N )
                N = 0;
            end
            if lat == 0
                lattxt = [ num2str(round(lat,N)) '°' ];
            elseif lat > 0
                lattxt = [ num2str(round(lat,N)) '°N' ];
            elseif lat < 0
                lattxt = [ num2str(round(-lat,N)) '°S' ];
            end
            if lon == 0 || lon == 180
                lontxt = [ num2str(round(lon,N)) '°' ];
            elseif lon > 0
                lontxt = [ num2str(round(lon,N)) '°E' ];
            elseif lon < 0
                lontxt = [ num2str(round(-lon,N)) '°W' ];
            end
        end

        % Compute cumulative arc length along the supplied set of
        % coordinates (longitude and colatitude).
        function sigmas = getCumArcLength( phis, thetas )
            theta1 = thetas(1:end-1);
            theta2 = thetas(2:end);
            phi1 = phis(1:end-1);
            phi2 = phis(2:end);
            dsigmas = acos( cos(theta1).*cos(theta2) + sin(theta1).*sin(theta2).*cos(phi2-phi1) );
            sigmas = [ 0; cumsum(dsigmas) ];
        end

        % Compute spherical median of a set of longitudes/colatitudes.
        function [ theta0, phi0, iter ] = sphericalMedian( theta, phi )

            % Convert to 3D unit vectors.
            V = BaseTools.sph2xyz(theta, phi);

            % Initial guess = normalized average vector.
            x = mean(V, 1);
            x = x / norm(x);

            % Iterate.
            for iter = 1:200
                d = sqrt(sum((V - x).^2, 2));      % Euclidean chord distances
                w = 1 ./ max(d, 1e-12);            % avoid singularities
                x_new = sum(V .* w, 1) / sum(w);   % weighted update
                x_new = x_new / norm(x_new);       % project back to sphere
                if norm(x_new - x) < 1e-9
                    break
                end
                x = x_new;
            end

            % Convert result back to spherical colatitude–longitude.
            [theta0, phi0] = BaseTools.xyz2sph(x);

        end

        % Convert colatitude and longitude to vectors.
        function V = sph2xyz(theta, phi)
            % theta: colatitude (0 = north pole)
            % phi:   longitude
            V = [sin(theta).*cos(phi), ...
                sin(theta).*sin(phi), ...
                cos(theta)];
        end

        % Convert vectors to colatitude and longitude.
        function [theta, phi] = xyz2sph(v)
            % v: Nx3 normalized vectors
            x = v(:,1); y = v(:,2); z = v(:,3);
            theta = acos(z);              % colatitude
            phi   = atan2(y, x);          % longitude
        end

        % Compute spherical distance between between two or more points on
        % a sphere, specified in terms of colatitude and longitude. All
        % angles are in radians.
        function d = sphdist(theta1, phi1, theta2, phi2)
            % Inputs:
            %   theta1, phi1  - colatitude and longitude of point 1
            %   theta2, phi2  - colatitude and longitude of point 2
            % Output:
            %   d - great-circle distance (radians)
            c = sin(theta1).*sin(theta2).*cos(phi1 - phi2) + cos(theta1).*cos(theta2); % dot product of the two unit vectors
            c = min(1, max(-1, c));   % clamp for numerical safety
            d = acos(c);
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
            if t_report > 1e-3
                str = sprintf( '%.3f %s', t_report, t_units );
            else
                str = sprintf( '%.3e %s', t_report, t_units );
            end
        end
        function progress_report( timername, k, N )
            % Since <timername> timer was started, we have completed k of N
            % steps. How are we doing and when will we be done? 
            t_elapsed = toc(timername);
            dt = (t_elapsed/k);
            report_on = unique( round( N*[ .001 .005 .01 .02 .03 .04 .05:.05:.95 ]' ) );
            if k == 1 || any( report_on == k )
                rt = dt*(N-k);
                etc = now + datenum(0,0,0,0,0,rt);
                fprintf( 'Completed %d/%d=%.1f%% in %s (%s each; %s remaining; ETC: %s).\n', k, N, 100*k/N, BaseTools.timetostr(t_elapsed), BaseTools.timetostr(dt), BaseTools.timetostr(rt), datestr(etc,13) );
            end
            
        end

        % Obtain a sequence with nice round steps.
        function steps = get_round_step_size( vals, target_N, centeronzero )
            if exist( 'centeronzero', 'var' ) && ~isempty( centeronzero ) && centeronzero
                vmax = max( abs(vals(:)) );
                vmin = -vmax;
            else
                vmin = min(vals(:));
                vmax = max(vals(:));
            end
            vwidth = vmax - vmin;
            if vwidth == 0
                steps = vmin;
            else
                ideal_step = vwidth/target_N;
                oom = floor( log10(ideal_step) );
                candidate_steps = [ 1 2 2.5 5 10 ]*10^oom;
                best = find( floor(vwidth./candidate_steps) <= target_N, 1, 'first' );
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
        function [ fi, ki ] = spaced_sequence( Nk, Nf )
            % Suppose you have a sequence from 1 to Nf but you only want
            % to retain Nk elements of this sequence, with the first and
            % last being retained for sure. The two outputs are: fi (the
            % full sequence from 1:Nf) and ki (indeces of the Nk elements
            % you will retain). If Nk > Nf, both results are 1:Nk.
            if Nf < Nk
                fi = 1:Nk;
                ki = fi;
            else
                fi = 1:Nf;
                ki = round(linspace(1,Nf,Nk));
            end
        end

        % Apply mapping with specified hard stops.
        function y = get_hard_stop_mapping( x, xrng, yrng )
            x = reshape(x,numel(x),1);
            if numel(xrng) ~= 2
                error( 'xrng must be a 2-element vector' );
            end
            [ rows, cols ] = size(yrng);
            if rows ~= 2
                error( 'yrng must be a 2xN array' );
            end
            slope = (yrng(2,:)-yrng(1,:)) / (xrng(2)-xrng(1));
            y = ( x - xrng(1) ) * slope + yrng(1,:);
            for j = 1 : cols
                y(x<min(xrng),j) = yrng(1,j);
                y(x>max(xrng),j) = yrng(2,j);
            end
        end

        % Turn a covariance matrix into an ellipse for plotting purposes.
        function [ Xe, Ye ] = covar_to_ellipse( full_covar )
            [ V, D ] = eig( full_covar );
            theta = 0:1:360;
            x = [ sqrt(D(2,2))*cosd(theta); sqrt(D(1,1))*sind(theta) ];
            B = V * x;
            Ye = - B(1,:);
            Xe = B(2,:);
        end
        
        % Rotation matrix stuff.
        function R = rpy2rot( roll, pitch, yaw, order, units )
            if ~exist( 'order', 'var' ) || isempty( order )
                order = 'zyx';
            end
            if ~exist( 'units', 'var' ) || isempty( units )
                units = 'degrees';
            end
            if strcmp( units, 'degrees' )
                roll = roll * pi/180;
                pitch = pitch * pi/180;
                yaw = yaw * pi/180;
            end
            Rz = [ cos(yaw) -sin(yaw) 0; sin(yaw) cos(yaw) 0; 0 0 1 ];
            Ry = [ cos(pitch) 0 sin(pitch); 0 1 0; -sin(pitch) 0 cos(pitch) ];
            Rx = [ 1 0 0; 0 cos(roll) -sin(roll); 0 sin(roll) cos(roll) ];
            if strcmp( order, 'xyz' )
                R = Rx * Ry * Rz;
            else
                R = Rz * Ry * Rx;
            end
        end

        % Draw coordinate frame.
        function drawFrame( ah, v, R, clr, lbls )
            if ~exist( 'clr', 'var' ) || isempty( clr )
                clr = zeros(1,3);
            end
            % Draw 3D arrows from the frame's origin.
            BaseTools.drawArrow( ah, v(1)+[ 0 R(1,1) ], v(2)+[ 0 R(1,2) ], v(3)+[ 0 R(1,3) ], 'Color', clr, 'LineWidth', 2.0 );
            BaseTools.drawArrow( ah, v(1)+[ 0 R(2,1) ], v(2)+[ 0 R(2,2) ], v(3)+[ 0 R(2,3) ], 'Color', clr, 'LineWidth', 2.0 );
            BaseTools.drawArrow( ah, v(1)+[ 0 R(3,1) ], v(2)+[ 0 R(3,2) ], v(3)+[ 0 R(3,3) ], 'Color', clr, 'LineWidth', 2.0 );
            % Add labels, displaced a little from the tips.
            f = 1.1;
            text( ah, v(1)+f*R(1,1), v(2)+f*R(1,2), v(3)+f*R(1,3), [ '$\hat{' lbls(1) '}$' ], 'Interpreter', 'latex', 'FontSize', 14, 'FontWeight', 'bold', 'Color', clr, 'HorizontalAlignment', 'center' );
            text( ah, v(1)+f*R(2,1), v(2)+f*R(2,2), v(3)+f*R(2,3), [ '$\hat{' lbls(2) '}$' ], 'Interpreter', 'latex', 'FontSize', 14, 'FontWeight', 'bold', 'Color', clr, 'HorizontalAlignment', 'center' );
            text( ah, v(1)+f*R(3,1), v(2)+f*R(3,2), v(3)+f*R(3,3), [ '$\hat{' lbls(3) '}$' ], 'Interpreter', 'latex', 'FontSize', 14, 'FontWeight', 'bold', 'Color', clr, 'HorizontalAlignment', 'center' );
        end

        % Draw a simple arrow ending with an arrowhead.
        function ah = drawArrow( varargin )
            args = BaseTools.argarray2struct( varargin, { 'Color', 'k' } );
            if isempty( args.posArgs )
                error( 'Not enough leading positional input arguments.' );
            else
                [ ah, ~ ] = BaseTools.verify_axes_handle( args.posArgs{1} );
                grid(ah,'on');
                hold(ah,'on');
                axis(ah,'equal');
                line_coords = BaseTools.filter_out_axes( args.posArgs );
                if length(line_coords)<2 || length(line_coords)>3
                    error( 'Need x,y or x,y,z coordinates for arrow.' );
                elseif length(line_coords)==2
                    % Here, we have an arrow in a 2D plane.
                    x = line_coords{1};
                    y = line_coords{2};
                    line( ah, x, y, 'LineWidth', 2.0, 'Color', args.Color );
                    if ~isfield( args, 'headlength' ) || isempty( args.headlength )
                        lens = sqrt( diff(x).^2 + diff(y).^2 );
                        full_length = sum(lens);
                        args.headlength = full_length/8;
                    end
                    if ~isfield( args, 'headwidth' ) || isempty( args.headwidth )
                        args.headwidth = args.headlength;
                    end
                    % Figure out final heading of arrow.
                    theta = atan2( y(end)-y(end-1), x(end)-x(end-1) );
                    hx = [ 0 -1 -1 ]*args.headlength;
                    hy = [ 0 1 -1 ]*args.headwidth/2;
                    fx = cos(theta)*hx - sin(theta)*hy + x(end);
                    fy = sin(theta)*hx + cos(theta)*hy + y(end);
                    ph = fill( fx, fy, args.Color );
                    ph.EdgeColor = args.Color;
                    ph.FaceColor = args.Color;
                elseif length(line_coords)==3
                    % Here, we need to draw a 3D arrow.
                    x = line_coords{1};
                    y = line_coords{2};
                    z = line_coords{3};
                    line( ah, x, y, z, 'LineWidth', 2.0, 'Color', args.Color );
                    if ~isfield( args, 'headlength' ) || isempty( args.headlength )
                        lens = sqrt( diff(x).^2 + diff(y).^2 + diff(z).^2 );
                        full_length = sum(lens);
                        args.headlength = full_length/8;
                    end
                    if ~isfield( args, 'headwidth' ) || isempty( args.headwidth )
                        args.headwidth = args.headlength/2;
                    end
                    % Build cone.
                    n = 18;
                    theta = linspace( 0, 2*pi, n );
                    hz = linspace( 0, -args.headlength, n );
                    [ Theta, hZ ] = meshgrid( theta, hz );
                    hR = args.headwidth * ( hZ/args.headlength );
                    hX = hR .* cos(Theta);
                    hY = hR .* sin(Theta);
                    % Translate and rotate cone to the arrow's terminus.
                    terminus = [ x(end); y(end); z(end) ];
                    tv = [ x(end)-x(end-1); y(end)-y(end-1); z(end)-z(end-1) ];
                    tv_hat = tv/norm(tv);
                    k = cross( [ 0 0 1 ]', tv_hat );
                    s = norm(k);
                    c = dot( [ 0 0 1 ]', tv_hat );
                    if s == 0
                        if c > 0
                            Rot = eye(3);
                        else
                            Rot = [ -1 0 0; 0 -1 0; 0 0 1 ];
                        end
                    else
                        k = k / s;  % Normalize rotation axis.
                        K = [ 0 -k(3) k(2); k(3) 0 -k(1); -k(2) k(1) 0 ];
                        Rot = eye(3) + K * s + K^2 * (1 - c);  % Rodrigues' rotation formula.
                    end
                    Head = Rot*[ hX(:)'; hY(:)'; hZ(:)' ] + terminus;
                    sh = surf( ah, reshape(Head(1,:),size(hX)), reshape(Head(2,:),size(hY)), reshape(Head(3,:),size(hZ)) );
                    sh.EdgeColor = 'none';
                    sh.FaceColor = args.Color;
                end
            end
        end

        % Group a bunch of figures into a tiled layout.
        function output_fig = tileFigures( input_fig_handles, rows, cols )

            % Establish the layout. The user may have supplied an array of
            % figure handles or a cell array containing figure handles.
            % Work out what they've done and proceed accodingly.
            if iscell(input_fig_handles)
                N1 = numel(input_fig_handles);
                if all( ishandle(input_fig_handles{1}) )
                    N2 = numel(input_fig_handles{1});
                    tmp_handles = gobjects(N1,N2);
                    for k = 1 : N1
                        tmp_handles(k,:) = input_fig_handles{k};
                    end
                else
                    error( 'Each cell in the input array must be an array of one or more figure handles.' );
                end
                input_fig_handles = tmp_handles;
            end
            N = numel(input_fig_handles);
            if ~exist( 'rows', 'var' ) || ~exist( 'cols', 'var' ) || (rows*cols~=N)
                % The user has not provided a valid layout so we'll need to
                % work that out internally.
                [ rows, cols ] = size( input_fig_handles );
                % rows = ceil(sqrt(N));
                % cols = ceil(N/rows);
            end
            output_fig = figure;
            th = tiledlayout(output_fig, rows, cols );
            th.Padding = 'compact';
            th.TileSpacing = 'compact';

            % Loop through each figure, moving its CurrentAxes over to the
            % new tiled layout and then closing the original figure. Since
            % the indexing proceeds in column order but the tile numbers do
            % not, we'll have to transpose the thing first.
            input_fig_handles = input_fig_handles';
            for i = 1 : N
                ah = input_fig_handles(i).CurrentAxes;
                ah.Parent = th;
                ah.Layout.Tile = i;
                close(input_fig_handles(i));
            end

            % Resize the figure to better accommodate all its tiles.
            b = output_fig.Position(4);
            output_fig.Position(3) = 140 + b * cols;
            output_fig.Position(4) = 140 + b * rows;
            output_fig.Position(1) = 1;

        end

        % Build a nice label from type and units.
        function disp_units = getDispUnits( type_txt, units_txt )
            if ~isempty( type_txt ) && ~isempty( units_txt )
                disp_units = [ type_txt ' (' units_txt ')' ];
            elseif ~isempty( type_txt ) && isempty( units_txt )
                disp_units = type_txt;
            elseif isempty( type_txt ) && ~isempty( units_txt )
                disp_units = units_txt;
            else
                disp_units = '';
            end
        end

        % Testing.
        function unit_test()

            % This is a disjointed collection of steps designed to exercise
            % much of the code in this toolset.

            % Setup.
            close all;
            mytimer = tic;

            % Draw some arrows and frames. This also implicitly verifies
            % argument parsing and figure/axes handle checking.
            x = linspace(0,pi);
            a1 = BaseTools.drawArrow( x, sin(x), 'Color', 'r' );
            [ a1, f1 ] = BaseTools.verify_axes_handle( a1 );
            BaseTools.drawArrow( a1, x, x, 'Color', [ 0 .6 .2 ], 'headlength', .2 );
            xlabel( BaseTools.getDispUnits( 'X-position', 'meters' ) );
            ylabel( BaseTools.getDispUnits( 'Y-position', '' ) );
            R = BaseTools.rpy2rot( -10, 5, 15 );
            BaseTools.drawFrame( a1, [ 0 0 0 ], eye(3), [ .2 .2 .4 ], 'xyz' );
            BaseTools.drawFrame( a1, [ -2 -1 0 ], R, 'b', 'ijk' );
            view( a1, [ 20 60 ] );

            % Example of displaying a constant.
            text( a1, 0, 3, sprintf( 'G = %.3e m^3kg^{-1}s^{-2}', BaseTools.G ) );

            % Example of a covariance ellipse.
            [ Xe, Ye ] = BaseTools.covar_to_ellipse( [ 1 .2; .2 1 ] );
            clr = [ .8 .2 .2 ];
            ph = patch( a1, Xe-2, Ye+2, clr );
            ph.FaceAlpha = 0.5;
            ph.EdgeColor = clr;
            ph.LineWidth = 2.0;

            % Example of a function you want to restrict to a specified range.
            x = linspace(-4,4);
            y = BaseTools.get_hard_stop_mapping( x, [ -1; 3 ], [ -2; 1 ] );
            plot( a1, x, y, 'm--', 'LineWidth', 2.0 );
            
            % Test some of the basic number manipulation stuff.
            [ a2, f2 ] = BaseTools.verify_axes_handle;
            hold( a2, 'on' );
            grid( a2, 'on' );
            [ fi, ki ] = BaseTools.spaced_sequence( 5, 12 );
            plot( a2, fi, zeros(size(fi)), 'ko' );
            plot( a2, ki, zeros(size(ki)), 'bo', 'MarkerSize', 12, 'MarkerFaceColor', 'b' );
            xlabel( 'Reduced sequence with approximately even spacing' );
            vals = linspace(-31,122,27);
            N = 11;
            steps = BaseTools.get_round_step_size( vals, N, true );
            plot( a2, zeros(size(vals)), vals, 'ko' );
            plot( a2, zeros(size(steps)), steps, 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r' );
            ylabel( 'Round and even step sizes' );
            a2.XLim(1) = -1;

            % Show some 3D rotations of vectors.
            [ a3, f3 ] = BaseTools.verify_axes_handle;
            hold( a3, 'on' );
            grid( a3, 'on' );

            % Draw an arc on geographic coordinates.
            R = 2;
            num_segs = 71;
            phis = linspace(0,1.1*pi,num_segs);
            thetas = linspace(0.1*pi,0.7*pi,num_segs);
            [ x, y, z ] = sph2cart( phis, pi/2-thetas, R );
            plot3( a3, x, y, z, 'k' );
            xlabel( 'x' );
            ylabel( 'y' );
            zlabel( 'z' );
            [ smooth_phis, smooth_thetas, smooth_sigmas ] = BaseTools.smoothShericalCoordinates( phis, thetas );
            [ x, y, z ] = sph2cart( smooth_phis, pi/2-smooth_thetas, R );
            plot3( a3, x, y, z, 'b--' );
            view( a3, [ -80 -10 ] );

            % Label at quasi-regular intervals.
            num_lbls = 5;
            [ ~, ki ] = BaseTools.spaced_sequence( num_lbls, num_segs );
            [ x, y, z ] = sph2cart( smooth_phis(ki), pi/2-smooth_thetas(ki), R );
            for k = 1 : num_lbls
                BaseTools.drawArrow( a3, [ 0 x(k) ], [ 0 y(k) ], [ 0 z(k) ], 'Color', [ k/num_lbls 0 0 ], 'headlength', .15 );
                text( a3, x(k), y(k), z(k), [ '\sigma = ' num2str(smooth_sigmas(k)) ], 'Color', [ k/num_lbls 0 0 ] );
            end

            % Show interpolated vectors between the last two big vectors.
            v = [ x(end-1:end)'; y(end-1:end)'; z(end-1:end)' ];
            vq = BaseTools.interp_vectors( [ 1 2 ], v, linspace(1,2,7) );
            N = size(vq,2);
            for k = 1 : N
                BaseTools.drawArrow( a3, [ 0 vq(1,k) ], [ 0 vq(2,k) ], [ 0 vq(3,k) ], 'Color', [ 0 0 k/N ], 'headlength', .07 );
                BaseTools.progress_report( mytimer, k, N );
            end

            % Merge the figures.
            BaseTools.tileFigures( [ f1 f2 f3 ] );

        end

    end
    
end

