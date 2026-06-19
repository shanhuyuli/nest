function G = nest_geometry(p)
% NEST_GEOMETRY 计算鸟巢双曲抛物面动画的全部几何数据
%   输入 p 结构体：a(长半轴), b(短半轴), c(翘起量), N(柱数), M_u, M_v(母线条数)
%   输出 G 结构体：pillars, rule_u, rule_v, surf_mesh, ellipse_pts
%
%   Example:
%     p = struct('a',6,'b',5,'c',2.5,'N',10,'M_u',9,'M_v',9);
%     G = nest_geometry(p);

% 参数校验
if p.N < 3
    error('NEST:pillarCount', '立柱数 N 必须 >= 3，当前 N=%d', p.N);
end
if p.a <= 0 || p.b <= 0
    error('NEST:ellipseAxis', '椭圆半轴 a,b 必须 > 0');
end
if p.M_u < 2, p.M_u = 2; end
if p.M_v < 2, p.M_v = 2; end

% 辅助函数：曲面 z 值
hpz = @(x, y) p.c * (x.^2/p.a^2 - y.^2/p.b^2);

% 立柱沿椭圆环均匀分布
theta = linspace(0, 2*pi, p.N+1);
theta = theta(1:p.N);  % 去掉闭合重复点 (theta=0 与 theta=2*pi)
x_p = p.a * cos(theta);
y_p = p.b * sin(theta);
z_p = hpz(x_p, y_p);  % 柱顶贴合曲面：z = c*(x^2/a^2 - y^2/b^2)
G.pillars = [x_p; y_p; z_p];  % 3xN 矩阵

% uv 域 -> xy 域映射（规范化标度）
uv2xy = @(u, v) deal(p.a*(u+v)/2, p.b*(v-u)/2);
uv2z  = @(u, v) p.c * u * v;

% u=const 组母线（v 从 -1 到 1）
G.rule_u = cell(1, p.M_u - 1);
for k = 1:(p.M_u - 1)
    u = -1 + 2*k/p.M_u;  % 跳过 u=-1 边界
    [x1, y1] = uv2xy(u, -1); z1 = uv2z(u, -1);
    [x2, y2] = uv2xy(u,  1); z2 = uv2z(u,  1);
    G.rule_u{k} = [x1 x2; y1 y2; z1 z2];  % 3x2：两端点
end

% v=const 组母线（u 从 -1 到 1）
G.rule_v = cell(1, p.M_v - 1);
for k = 1:(p.M_v - 1)
    v = -1 + 2*k/p.M_v;  % 跳过 v=-1 边界
    [x1, y1] = uv2xy(-1, v); z1 = uv2z(-1, v);
    [x2, y2] = uv2xy( 1, v); z2 = uv2z( 1, v);
    G.rule_v{k} = [x1 x2; y1 y2; z1 z2];  % 3x2：两端点
end

% 曲面网格（供 surf 半透明面片）
[xg, yg] = meshgrid(linspace(-p.a, p.a, 30), linspace(-p.b, p.b, 30));
zg = hpz(xg, yg);
G.surf_mesh = struct('X', xg, 'Y', yg, 'Z', zg);

% 椭圆地面环采样（供 plot3 地面环）
ell_theta = linspace(0, 2*pi, 200);
G.ellipse_pts = [p.a * cos(ell_theta); p.b * sin(ell_theta)];

end
