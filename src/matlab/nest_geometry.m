function G = nest_geometry(p)
% NEST_GEOMETRY 计算鸟巢双曲抛物面动画的全部几何数据
%   输入 p 结构体（可选，字段覆盖默认值）或空
%   输出 G 结构体：pillars, roof_segments, ellipse_outer, ellipse_inner
%
%   Example:
%     G = nest_geometry([]);

% ===== 默认参数（原型验证通过）=====
ahp     = 80;
bhp     = 72;
c_val   = 18;
z_offset = 23.2;
a_out   = 60;
b_out   = 53.5;
a_in    = 34.4;
b_in    = 22.4;
Nu      = 50;
Nv      = 50;
u_range = [-1.06, 1.06];
v_range = [-1.06, 1.06];

% ===== 用户参数覆盖 =====
if nargin >= 1 && ~isempty(p) && isstruct(p)
    if isfield(p,'ahp'),     ahp     = p.ahp;     end
    if isfield(p,'bhp'),     bhp     = p.bhp;     end
    if isfield(p,'c'),       c_val   = p.c;       end
    if isfield(p,'z_offset'),z_offset= p.z_offset; end
    if isfield(p,'a_out'),   a_out   = p.a_out;   end
    if isfield(p,'b_out'),   b_out   = p.b_out;   end
    if isfield(p,'a_in'),    a_in    = p.a_in;    end
    if isfield(p,'b_in'),    b_in    = p.b_in;    end
    if isfield(p,'Nu'),      Nu      = p.Nu;      end
    if isfield(p,'Nv'),      Nv      = p.Nv;      end
end

% ===== 参数校验 =====
if ahp <= 0 || bhp <= 0, error('NEST:param','ahp,bhp must be > 0'); end
if a_out <= 0 || b_out <= 0, error('NEST:param','a_out,b_out must be > 0'); end
if a_in <= 0 || b_in <= 0, error('NEST:param','a_in,b_in must be > 0'); end
if Nu < 2, Nu = 2; end
if Nv < 2, Nv = 2; end

% ===== HP 曲面高度函数 =====
hpZ = @(x,y) c_val * (x.^2 ./ ahp^2 - y.^2 ./ bhp^2) + z_offset;

% ===== 初始化 =====
pillars = [];       % [x, y, z_base(=0), z_top]
roof_segments = {};  % 每个 cell: [x1 y1 z1; x2 y2 z2]

% ===== u 族直母线: x/ahp - y/bhp = u, 斜率 = +bhp/ahp =====
u_vals = linspace(u_range(1), u_range(2), Nu);
slope_u = bhp / ahp;

for ui = 1:Nu
    u = u_vals(ui);
    d = -slope_u * ahp * u;
    m = slope_u;

    pts_out = lineEllipseIntersect(m, d, a_out, b_out);
    pts_in  = lineEllipseIntersect(m, d, a_in, b_in);

    all_pts = [];
    if ~isempty(pts_out)
        for j = 1:size(pts_out,1)
            all_pts = [all_pts; pts_out(j,1), pts_out(j,2), 1, pts_out(j,1)];
        end
    end
    if ~isempty(pts_in)
        for j = 1:size(pts_in,1)
            all_pts = [all_pts; pts_in(j,1), pts_in(j,2), 2, pts_in(j,1)];
        end
    end

    if size(all_pts,1) >= 2
        [~, idx] = sort(all_pts(:,4));
        all_pts = all_pts(idx, :);
        for j = 1:size(all_pts,1)-1
            p1 = all_pts(j, 1:2);
            p2 = all_pts(j+1, 1:2);
            t1 = all_pts(j, 3);
            t2 = all_pts(j+1, 3);
            if t1 == 2 && t2 == 2, continue; end
            mid_x = (p1(1)+p2(1))/2;
            mid_y = (p1(2)+p2(2))/2;
            if pointInEllipse(mid_x, mid_y, a_in, b_in), continue; end
            z1 = hpZ(p1(1), p1(2));
            z2 = hpZ(p2(1), p2(2));
            pillars = [pillars; p1(1), p1(2), 0, z1];
            pillars = [pillars; p2(1), p2(2), 0, z2];
            roof_segments{end+1} = [p1(1), p1(2), z1; p2(1), p2(2), z2];
        end
    end
end

% ===== v 族直母线: x/ahp + y/bhp = v, 斜率 = -bhp/ahp =====
v_vals = linspace(v_range(1), v_range(2), Nv);
slope_v = -bhp / ahp;

for vi = 1:Nv
    v = v_vals(vi);
    d = -slope_v * ahp * v;
    m = slope_v;

    pts_out = lineEllipseIntersect(m, d, a_out, b_out);
    pts_in  = lineEllipseIntersect(m, d, a_in, b_in);

    all_pts = [];
    if ~isempty(pts_out)
        for j = 1:size(pts_out,1)
            all_pts = [all_pts; pts_out(j,1), pts_out(j,2), 1, pts_out(j,1)];
        end
    end
    if ~isempty(pts_in)
        for j = 1:size(pts_in,1)
            all_pts = [all_pts; pts_in(j,1), pts_in(j,2), 2, pts_in(j,1)];
        end
    end

    if size(all_pts,1) >= 2
        [~, idx] = sort(all_pts(:,4));
        all_pts = all_pts(idx, :);
        for j = 1:size(all_pts,1)-1
            p1 = all_pts(j, 1:2);
            p2 = all_pts(j+1, 1:2);
            t1 = all_pts(j, 3);
            t2 = all_pts(j+1, 3);
            if t1 == 2 && t2 == 2, continue; end
            mid_x = (p1(1)+p2(1))/2;
            mid_y = (p1(2)+p2(2))/2;
            if pointInEllipse(mid_x, mid_y, a_in, b_in), continue; end
            z1 = hpZ(p1(1), p1(2));
            z2 = hpZ(p2(1), p2(2));
            pillars = [pillars; p1(1), p1(2), 0, z1];
            pillars = [pillars; p2(1), p2(2), 0, z2];
            roof_segments{end+1} = [p1(1), p1(2), z1; p2(1), p2(2), z2];
        end
    end
end

% ===== 椭圆轮廓（供地面参考线）=====
theta = linspace(0, 2*pi, 200);
G.ellipse_outer = [a_out * cos(theta); b_out * sin(theta)];
G.ellipse_inner = [a_in * cos(theta); b_in * sin(theta)];
G.pillars = pillars;
G.roof_segments = roof_segments;
G.u_count = Nu;
G.v_count = Nv;

end  % nest_geometry

%% ===== LOCAL FUNCTIONS =====

function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
% 直线 y = m*x + d 与椭圆 (x/a)^2 + (y/b)^2 = 1 的交点
    A = 1/a_ell^2 + m^2/b_ell^2;
    B = 2*m*d/b_ell^2;
    C = d^2/b_ell^2 - 1;
    disc = B^2 - 4*A*C;
    if disc < 0
        pts = [];
    elseif disc < 1e-12
        x = -B/(2*A);
        pts = [x, m*x + d];
    else
        x1 = (-B + sqrt(disc))/(2*A);
        x2 = (-B - sqrt(disc))/(2*A);
        pts = [x1, m*x1 + d; x2, m*x2 + d];
    end
end

function inside = pointInEllipse(x, y, a_ell, b_ell)
% 判断点是否在椭圆内部
    inside = (x^2/a_ell^2 + y^2/b_ell^2) < 1;
end
