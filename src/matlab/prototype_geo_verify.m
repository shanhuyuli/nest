% PROTOTYPE — THROWAWAY: Verify nest geometry before building full animation
% Question: Does the HP ruled-surface + ellipse intersection logic produce 
%           the correct Bird's Nest visual structure?
% Run:     matlab -batch "cd('D:/Workspace/nest'); run('src/matlab/prototype_geo_verify.m');"

clear; close all; clc;

%% ===== PARAMETERS (from spec, adjusted for prototype) =====
ahp = 80;       % HP a parameter (curvature control)
bhp = 72;       % HP b parameter
c   = 11.25;    % Saddle scale (5/6 of 13.5)
z0  = 19.6;     % Vertical offset (5/6 of 23.5)
                % z_min ≈ 13.4, z_max ≈ 25.9

a_out = 60;  b_out = 53.5;   % Outer ellipse
a_in  = 34.4; b_in  = 22.4;  % Inner ellipse (roof opening)

Nu = 48;       % u-family count (close to final spec of 50)
Nv = 48;       % v-family count (close to final spec of 50)
u_range = [-1.06, 1.06];
v_range = [-1.06, 1.06];

%% ===== CORE FUNCTIONS =====
hpZ = @(x,y) c * (x.^2 ./ ahp^2 - y.^2 ./ bhp^2) + z0;

%% ===== GENERATE RULINGS AND COMPUTE GEOMETRY =====

pillars = [];      % Each row: [x, y, z_base, z_top]
roof_segments = {}; % Cell array

% --- u-family: x/ahp - y/bhp = u, slope = +bhp/ahp ---
u_vals = linspace(u_range(1), u_range(2), Nu);
slope_u = bhp / ahp;

fprintf('Processing u-family rulings...\n');
for ui = 1:Nu
    u = u_vals(ui);
    d = -slope_u * ahp * u;
    m = slope_u;
    
    pts_out = lineEllipseIntersect(m, d, a_out, b_out);
    pts_in  = lineEllipseIntersect(m, d, a_in, b_in);
    
    all_pts = [];
    if ~isempty(pts_out)
        for j = 1:size(pts_out, 1)
            xp = pts_out(j,1); yp = pts_out(j,2);
            all_pts = [all_pts; xp, yp, 1, xp];
        end
    end
    if ~isempty(pts_in)
        for j = 1:size(pts_in, 1)
            xp = pts_in(j,1); yp = pts_in(j,2);
            all_pts = [all_pts; xp, yp, 2, xp];
        end
    end
    
    if size(all_pts, 1) >= 2
        [~, idx] = sort(all_pts(:,4));
        all_pts = all_pts(idx, :);
        
        for j = 1:size(all_pts, 1)-1
            p1 = all_pts(j, 1:2);
            p2 = all_pts(j+1, 1:2);
            t1 = all_pts(j, 3);      t2 = all_pts(j+1, 3);
            
            if t1 == 2 && t2 == 2; continue; end
            
            mid_x = (p1(1) + p2(1))/2;
            mid_y = (p1(2) + p2(2))/2;
            if pointInEllipse(mid_x, mid_y, a_in, b_in); continue; end
            
            z1 = hpZ(p1(1), p1(2));
            z2 = hpZ(p2(1), p2(2));
            pillars = [pillars; p1(1), p1(2), 0, z1];
            pillars = [pillars; p2(1), p2(2), 0, z2];
            roof_segments{end+1} = [p1(1), p1(2), z1; p2(1), p2(2), z2];
        end
    end
end

% --- v-family: x/ahp + y/bhp = v, slope = -bhp/ahp ---
v_vals = linspace(v_range(1), v_range(2), Nv);
slope_v = -bhp / ahp;

fprintf('Processing v-family rulings...\n');
for vi = 1:Nv
    v = v_vals(vi);
    d = -slope_v * ahp * v;
    m = slope_v;
    
    pts_out = lineEllipseIntersect(m, d, a_out, b_out);
    pts_in  = lineEllipseIntersect(m, d, a_in, b_in);
    
    all_pts = [];
    if ~isempty(pts_out)
        for j = 1:size(pts_out, 1)
            xp = pts_out(j,1); yp = pts_out(j,2);
            all_pts = [all_pts; xp, yp, 1, xp];
        end
    end
    if ~isempty(pts_in)
        for j = 1:size(pts_in, 1)
            xp = pts_in(j,1); yp = pts_in(j,2);
            all_pts = [all_pts; xp, yp, 2, xp];
        end
    end
    
    if size(all_pts, 1) >= 2
        [~, idx] = sort(all_pts(:,4));
        all_pts = all_pts(idx, :);
        
        for j = 1:size(all_pts, 1)-1
            p1 = all_pts(j, 1:2);
            p2 = all_pts(j+1, 1:2);
            t1 = all_pts(j, 3);      t2 = all_pts(j+1, 3);
            
            if t1 == 2 && t2 == 2; continue; end
            
            mid_x = (p1(1) + p2(1))/2;
            mid_y = (p1(2) + p2(2))/2;
            if pointInEllipse(mid_x, mid_y, a_in, b_in); continue; end
            
            z1 = hpZ(p1(1), p1(2));
            z2 = hpZ(p2(1), p2(2));
            pillars = [pillars; p1(1), p1(2), 0, z1];
            pillars = [pillars; p2(1), p2(2), 0, z2];
            roof_segments{end+1} = [p1(1), p1(2), z1; p2(1), p2(2), z2];
        end
    end
end

%% ===== STATISTICS =====
fprintf('\n===== PROTOTYPE GEOMETRY VERIFICATION =====\n');
fprintf('HP: ahp=%.1f, bhp=%.1f, c=%.1f, z_offset=%.1f\n', ahp, bhp, c, z0);
fprintf('Ellipses: outer(%.1f,%.1f), inner(%.1f,%.1f)\n', a_out, b_out, a_in, b_in);
fprintf('Rulings: u-family=%d, v-family=%d\n', Nu, Nv);
fprintf('Total pillars (with duplicates): %d\n', size(pillars, 1));
fprintf('Total roof segments: %d\n', length(roof_segments));
fprintf('Pillar height range: [%.2f, %.2f]\n', min(pillars(:,4)), max(pillars(:,4)));

max_err = 0;
for i = 1:min(size(pillars,1), 2000)
    z_calc = hpZ(pillars(i,1), pillars(i,2));
    err = abs(z_calc - pillars(i,4));
    max_err = max(max_err, err);
end
fprintf('Max pillar-top vs HP error: %.2e (should be approx 0)\n', max_err);

midpoint_errors = [];
for i = 1:length(roof_segments)
    seg = roof_segments{i};
    mid_x = (seg(1,1) + seg(2,1))/2;
    mid_y = (seg(1,2) + seg(2,2))/2;
    mid_z = (seg(1,3) + seg(2,3))/2;
    z_surf = hpZ(mid_x, mid_y);
    midpoint_errors = [midpoint_errors; abs(mid_z - z_surf)];
end
fprintf('Max ruling-midpoint vs HP error: %.2e (should be approx 0)\n', max(midpoint_errors));
fprintf('Avg ruling-midpoint error: %.2e\n', mean(midpoint_errors));

%% ===== 3D RENDERING =====
figure('Name', 'PROTOTYPE: Nest Geometry Verify', 'Position', [100, 100, 900, 700]);
hold on; grid on;
% Use pbaspect to give Z more visual weight (without distorting geometry)
daspect([1 1 1]);  % Equal aspect now appropriate (height ≈ width)

for i = 1:size(pillars, 1)
    plot3([pillars(i,1), pillars(i,1)], [pillars(i,2), pillars(i,2)], ...
          [pillars(i,3), pillars(i,4)], 'Color', [0.75 0.75 0.75], 'LineWidth', 3);
end

for i = 1:length(roof_segments)
    seg = roof_segments{i};
    plot3([seg(1,1), seg(2,1)], [seg(1,2), seg(2,2)], ...
          [seg(1,3), seg(2,3)], 'Color', [0.93, 0.69, 0.13], 'LineWidth', 2);
end

theta = linspace(0, 2*pi, 200);
x_out = a_out * cos(theta); y_out = b_out * sin(theta);
plot3(x_out, y_out, zeros(size(theta)), 'k--', 'LineWidth', 1);
x_in = a_in * cos(theta); y_in = b_in * sin(theta);
plot3(x_in, y_in, zeros(size(theta)), 'k:', 'LineWidth', 1);

xlabel('X'); ylabel('Y'); zlabel('Z');
zlim([0, max(pillars(:,4)) * 1.1]);
title(sprintf('PROTOTYPE: %du+%dv rulings, %d pillars, %d segments', ...
    Nu, Nv, size(pillars,1), length(roof_segments)));
view(-35, 30);

% Save image for inspection
mkdir('tmp');
saveas(gcf, 'tmp/prototype_geo_verify.png');
fprintf('\nFigure saved to tmp/prototype_geo_verify.png\n');
fprintf('===== PROTOTYPE COMPLETE =====\n');

%% ===== LOCAL FUNCTIONS (must be at end in MATLAB scripts) =====

function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
    A = 1/a_ell^2 + m^2/b_ell^2;
    B = 2*m*d/b_ell^2;
    C = d^2/b_ell^2 - 1;
    disc = B^2 - 4*A*C;
    if disc < 0
        pts = [];
    elseif disc < 1e-12
        x = -B/(2*A);
        y = m*x + d;
        pts = [x, y];
    else
        x1 = (-B + sqrt(disc))/(2*A);
        x2 = (-B - sqrt(disc))/(2*A);
        y1 = m*x1 + d;
        y2 = m*x2 + d;
        pts = [x1, y1; x2, y2];
    end
end

function inside = pointInEllipse(x, y, a_ell, b_ell)
    inside = (x^2/a_ell^2 + y^2/b_ell^2) < 1;
end
