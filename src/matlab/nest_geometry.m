function G = nest_geometry(p)
% NEST_GEOMETRY 计算鸟巢双曲抛物面动画的全部几何数据 (Iteration 2)
if nargin < 1 || isempty(p) || ~isstruct(p)
    ahp = 80; bhp = 72; c_val = 18; z_offset = 23.2;
    a_out = 60; b_out = 53.5; a_in = 34.4; b_in = 22.4;
    Nu = 50; Nv = 50;
    u_range = [-1.06, 1.06]; v_range = [-1.06, 1.06];
else
    ahp = p.ahp; bhp = p.bhp; c_val = p.c; z_offset = p.z_offset;
    a_out = p.a_out; b_out = p.b_out; a_in = p.a_in; b_in = p.b_in;
    Nu = p.Nu; Nv = p.Nv;
    u_range = p.u_range; v_range = p.v_range;
end
hpZ = @(x,y) c_val*(x.^2/ahp^2 - y.^2/bhp^2) + z_offset;
pillars = []; roof_segments = {};
slope_u = bhp/ahp; slope_v = -bhp/ahp;
u_vals = linspace(u_range(1), u_range(2), Nu);
for ui = 1:Nu
    d = -slope_u*ahp*u_vals(ui);
    [pillars, roof_segments] = processRuling(slope_u, d, a_out, b_out, a_in, b_in, hpZ, pillars, roof_segments);
end
v_vals = linspace(v_range(1), v_range(2), Nv);
for vi = 1:Nv
    d = -slope_v*ahp*v_vals(vi);
    [pillars, roof_segments] = processRuling(slope_v, d, a_out, b_out, a_in, b_in, hpZ, pillars, roof_segments);
end
theta = linspace(0, 2*pi, 200);
G.ellipse_outer = [a_out*cos(theta); b_out*sin(theta)];
G.ellipse_inner = [a_in*cos(theta); b_in*sin(theta)];
G.pillars = pillars; G.roof_segments = roof_segments;
G.u_count = Nu; G.v_count = Nv;
end

function [pillars, roof_segments] = processRuling(m, d, a_out, b_out, a_in, b_in, hpZ, pillars, roof_segments)
pts_out = lineEllipseIntersect(m, d, a_out, b_out);
pts_in  = lineEllipseIntersect(m, d, a_in, b_in);
all_pts = [];
if ~isempty(pts_out)
    for j = 1:size(pts_out,1), all_pts = [all_pts; pts_out(j,1), pts_out(j,2), 1, pts_out(j,1)]; end
end
if ~isempty(pts_in)
    for j = 1:size(pts_in,1), all_pts = [all_pts; pts_in(j,1), pts_in(j,2), 2, pts_in(j,1)]; end
end
if size(all_pts,1) < 2, return; end
[~, idx] = sort(all_pts(:,4)); all_pts = all_pts(idx, :);
for j = 1:size(all_pts,1)-1
    p1 = all_pts(j,1:2); p2 = all_pts(j+1,1:2);
    t1 = all_pts(j,3); t2 = all_pts(j+1,3);
    if t1 == 2 && t2 == 2, continue; end
    mx = (p1(1)+p2(1))/2; my = (p1(2)+p2(2))/2;
    if pointInEllipse(mx, my, a_in, b_in), continue; end
    z1 = hpZ(p1(1),p1(2)); z2 = hpZ(p2(1),p2(2));
    pillars = [pillars; p1(1),p1(2),0,z1; p2(1),p2(2),0,z2];
    roof_segments{end+1} = [p1(1),p1(2),z1; p2(1),p2(2),z2];
end
end

function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
A = 1/a_ell^2 + m^2/b_ell^2; B = 2*m*d/b_ell^2; Cc = d^2/b_ell^2 - 1;
disc = B^2 - 4*A*Cc;
if disc < 0, pts = [];
elseif disc < 1e-12, x = -B/(2*A); pts = [x, m*x+d];
else, x1 = (-B+sqrt(disc))/(2*A); x2 = (-B-sqrt(disc))/(2*A); pts = [x1, m*x1+d; x2, m*x2+d];
end
end

function inside = pointInEllipse(x, y, a_ell, b_ell)
inside = (x^2/a_ell^2 + y^2/b_ell^2) < 1;
end
