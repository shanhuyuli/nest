# 鸟巢双曲抛物面动画 · 迭代2 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于实际鸟巢构造原理重构 MATLAB 动画，并同步实现 Python 版本 —— 双语言独立的双曲抛物面直纹面教学演示。

**Architecture:** 过程式三文件架构（Geometry → Animation → Driver），MATLAB 和 Python 各自独立实现相同数学逻辑。纯函数 Geometry 模块可独立单元测试，Animation 操作图形渲染。

**Tech Stack:** MATLAB R2021b / Python 3 + numpy + matplotlib + pytest

**关联文档:**
- Spec: `docs/superpowers/specs/2026-06-19-nest-iteration2-design.md`
- PRD: `docs/superpowers/prd/nest-iteration2-prd.md`
- Issues: #6, #7, #8, #9, #10, #11, #12

---

## 依赖关系

```
#6 (MATLAB Geometry) ──→ #7 (MATLAB Tests) ──→ #8 (MATLAB Animation+Driver)
                                                       │
#9 (Python Geometry) ──→ #10 (Python Tests) ──→ #11 (Python Animation+Driver)
                                                       │
                                    #12 (Cleanup+README) ←─────────────────┘
```

- **可并行**: [#6, #9] 同时启动；[#7, #10] 在各自 Geometry 完成后并行
- **顺序**: #7 依赖 #6；#10 依赖 #9；#8 依赖 #6+#7；#11 依赖 #9+#10；#12 依赖 #8+#11

---

## 全局常量（所有 Task 共用）

```matlab
% MATLAB
ahp = 80;  bhp = 72;  c = 18;  z_offset = 23.2;
a_out = 60;  b_out = 53.5;  a_in = 34.4;  b_in = 22.4;
Nu = 50;  Nv = 50;  u_range = [-1.06, 1.06];  v_range = [-1.06, 1.06];
az_view = -20;  el_view = 25;
pillar_color = [0.75 0.75 0.75];  pillar_lw = 3;
roof_color = [0.93 0.69 0.13];    roof_lw = 2;  % #EDB120/255
```

```python
# Python
AHP = 80; BHP = 72; C = 18; Z_OFFSET = 23.2
A_OUT = 60; B_OUT = 53.5; A_IN = 34.4; B_IN = 22.4
NU = 50; NV = 50; U_RANGE = (-1.06, 1.06); V_RANGE = (-1.06, 1.06)
AZ_VIEW = -20; EL_VIEW = 25
PILLAR_COLOR = '#BFBFBF'  # [0.75 0.75 0.75]
ROOF_COLOR = '#EDB120'
```

---

### Task 1: MATLAB — 重构 nest_geometry.m 几何引擎 → [#6]

**Files:**
- Modify: `src/matlab/nest_geometry.m`

**输出结构体 `G`：**
```
G.pillars       — [N×4] 每行 [x, y, z_base(=0), z_top]
G.roof_segments — cell array, 每个 {2×3} [x1 y1 z1; x2 y2 z2]
G.ellipse_outer — [2×200] 外椭圆轮廓 (供地面参考线)
G.ellipse_inner — [2×200] 内椭圆轮廓
G.u_count       — 实际产生的 u 族母线条数
G.v_count       — 实际产生的 v 族母线条数
```

- [ ] **Step 1: 在文件顶部替换参数区和 HP 函数**

将旧参数替换为全局常量。删除旧的 `pillars`、`rule_u`、`rule_v`、`surf_mesh` 计算逻辑。保留参数校验（`N≥3`, `a>0`, `c≥0`），新增 `Nu≥2`, `Nv≥2` 校验。

```matlab
function G = nest_geometry(p)
% NEST_GEOMETRY 计算鸟巢双曲抛物面动画的全部几何数据
%   输入 p 结构体或直接使用全局常量

% 参数（如未传入 p 则使用默认值）
if nargin < 1 || isempty(p)
    ahp = 80;  bhp = 72;  c = 18;  z_offset = 23.2;
    a_out = 60;  b_out = 53.5;  a_in = 34.4;  b_in = 22.4;
    Nu = 50;  Nv = 50;
    u_range = [-1.06, 1.06];  v_range = [-1.06, 1.06];
else
    ahp = p.ahp;  bhp = p.bhp;  c = p.c;  z_offset = p.z_offset;
    a_out = p.a_out;  b_out = p.b_out;  a_in = p.a_in;  b_in = p.b_in;
    Nu = p.Nu;  Nv = p.Nv;
    u_range = p.u_range;  v_range = p.v_range;
end

% HP 曲面辅助函数
hpZ = @(x,y) c * (x.^2 ./ ahp^2 - y.^2 ./ bhp^2) + z_offset;
```

- [ ] **Step 2: 实现 `lineEllipseIntersect` 局部函数**

在文件末尾 `%% LOCAL FUNCTIONS` 区域添加：

```matlab
function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
% 直线 y = m*x + d 与椭圆 (x/a)^2 + (y/b)^2 = 1 的交点
% 返回 [x1 y1; x2 y2] (2个交点), [x1 y1] (1个切点), 或 [] (无交点)
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
```

- [ ] **Step 3: 实现 `pointInEllipse` 局部函数**

```matlab
function inside = pointInEllipse(x, y, a_ell, b_ell)
    inside = (x^2/a_ell^2 + y^2/b_ell^2) < 1;
end
```

- [ ] **Step 4: 实现 u 族直母线处理循环**

```matlab
pillars = [];  % [x, y, z_base, z_top]
roof_segments = {};

u_vals = linspace(u_range(1), u_range(2), Nu);
slope_u = bhp / ahp;

for ui = 1:Nu
    u = u_vals(ui);
    d = -slope_u * ahp * u;  % y = slope_u * x + d
    m = slope_u;

    pts_out = lineEllipseIntersect(m, d, a_out, b_out);
    pts_in  = lineEllipseIntersect(m, d, a_in, b_in);

    all_pts = [];  % [x, y, type, t_param]
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
            p1 = all_pts(j, 1:2);  p2 = all_pts(j+1, 1:2);
            t1 = all_pts(j, 3);    t2 = all_pts(j+1, 3);
            if t1 == 2 && t2 == 2, continue; end
            mid_x = (p1(1) + p2(1))/2;  mid_y = (p1(2) + p2(2))/2;
            if pointInEllipse(mid_x, mid_y, a_in, b_in), continue; end
            z1 = hpZ(p1(1), p1(2));  z2 = hpZ(p2(1), p2(2));
            pillars = [pillars; p1(1), p1(2), 0, z1];
            pillars = [pillars; p2(1), p2(2), 0, z2];
            roof_segments{end+1} = [p1(1), p1(2), z1; p2(1), p2(2), z2];
        end
    end
end
```

- [ ] **Step 5: 实现 v 族直母线处理循环**

与 Step 4 镜像，仅斜率变为 `slope_v = -bhp / ahp`，参数为 `v_vals`：

```matlab
v_vals = linspace(v_range(1), v_range(2), Nv);
slope_v = -bhp / ahp;

for vi = 1:Nv
    v = v_vals(vi);
    d = -slope_v * ahp * v;
    m = slope_v;
    % ... 与 Step 4 完全相同的交点处理和线段连接逻辑 ...
end
```

- [ ] **Step 6: 生成椭圆轮廓并打包输出**

```matlab
theta = linspace(0, 2*pi, 200);
G.ellipse_outer = [a_out * cos(theta); b_out * sin(theta)];
G.ellipse_inner = [a_in * cos(theta); b_in * sin(theta)];
G.pillars = pillars;
G.roof_segments = roof_segments;
G.u_count = Nu;
G.v_count = Nv;
end  % nest_geometry
```

- [ ] **Step 7: 在 MATLAB 中验证函数可运行**

```bash
matlab -batch "cd('D:/Workspace/nest'); G = nest_geometry([]); fprintf('pillars=%d segments=%d\n', size(G.pillars,1), length(G.roof_segments));"
```

预期输出：`pillars≈280 segments≈140`

- [ ] **Step 8: Commit**

```bash
git add src/matlab/nest_geometry.m
git commit -m "feat: refactor nest_geometry with HP ruled surface and inner/outer ellipses"
```

---

### Task 2: MATLAB — 新增 test_nest_geometry.m 单元测试 → [#7]

**Files:**
- Create: `src/matlab/test/test_nest_geometry.m`

- [ ] **Step 1: 创建测试文件骨架**

```matlab
% TEST_NEST_GEOMETRY 验证 nest_geometry 几何计算正确性
function test_nest_geometry
    fprintf('=== nest_geometry Unit Tests ===\n');
    passed = 0;  failed = 0;

    function assert_pass(cond, msg)
        if cond
            passed = passed + 1;  fprintf('  PASS: %s\n', msg);
        else
            failed = failed + 1;  fprintf('  FAIL: %s\n', msg);
        end
    end
```

- [ ] **Step 2: 测试1 — hyperboloidZ 函数**

```matlab
    % Test 1: HP surface height
    G = nest_geometry([]);
    fprintf('\nTest 1: hyperboloidZ values\n');
    % 手动计算已知点: (60,0) → z_max, (0,53.5) → z_min
    hpZ = @(x,y) 18*(x.^2/6400 - y.^2/5184) + 23.2;
    assert_pass(abs(hpZ(60,0) - 33.325) < 0.01, 'z at (60,0) correct');
    assert_pass(abs(hpZ(0,53.5) - 13.263) < 0.01, 'z at (0,53.5) correct');
    assert_pass(hpZ(0,0) == 23.2, 'z at origin = z_offset');
```

- [ ] **Step 3: 测试2 — lineEllipseIntersect**

```matlab
    % Test 2: line-ellipse intersection
    fprintf('\nTest 2: lineEllipseIntersect\n');
    % 水平线 y=0 与外椭圆: 交点应在 (±60, 0)
    pts = lineEllipseIntersect(0, 0, 60, 53.5);
    assert_pass(size(pts,1)==2, 'horizontal line gives 2 intersections');
    assert_pass(abs(abs(pts(1,1))-60) < 1e-10, 'x-coord correct');
    % 线 y=100 不经过椭圆: 0 交点
    pts = lineEllipseIntersect(0, 100, 60, 53.5);
    assert_pass(isempty(pts), 'far line gives 0 intersections');
```

- [ ] **Step 4: 测试3 — 直母线中点在 HP 曲面上**

```matlab
    % Test 3: ruling midpoints lie on HP surface
    fprintf('\nTest 3: ruling midpoints on HP surface\n');
    G = nest_geometry([]);
    max_err = 0;
    for i = 1:length(G.roof_segments)
        seg = G.roof_segments{i};
        mx = (seg(1,1)+seg(2,1))/2;  my = (seg(1,2)+seg(2,2))/2;
        mz = (seg(1,3)+seg(2,3))/2;
        z_surf = 18*(mx^2/6400 - my^2/5184) + 23.2;
        max_err = max(max_err, abs(mz - z_surf));
    end
    assert_pass(max_err < 1e-10, ...
        sprintf('max ruling midpoint error %.2e < 1e-10', max_err));
```

- [ ] **Step 5: 测试4 — 立柱顶端在 HP 曲面上 + 最小高度**

```matlab
    % Test 4: pillar tops on HP surface + minimum height
    fprintf('\nTest 4: pillar properties\n');
    min_z = inf;  max_pillar_err = 0;
    for i = 1:size(G.pillars,1)
        x = G.pillars(i,1);  y = G.pillars(i,2);  zt = G.pillars(i,4);
        z_surf = 18*(x^2/6400 - y^2/5184) + 23.2;
        max_pillar_err = max(max_pillar_err, abs(zt - z_surf));
        min_z = min(min_z, zt);
    end
    assert_pass(max_pillar_err < 1e-10, ...
        sprintf('max pillar error %.2e', max_pillar_err));
    assert_pass(min_z >= 13, sprintf('min pillar height %.1f >= 13', min_z));
```

- [ ] **Step 6: 打印结果并结束**

```matlab
    fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
    if failed > 0, error('TESTS FAILED'); end
end
```

- [ ] **Step 7: 声明局部函数（复用原型中的）**

```matlab
function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
    A = 1/a_ell^2 + m^2/b_ell^2;  B = 2*m*d/b_ell^2;  C = d^2/b_ell^2 - 1;
    disc = B^2 - 4*A*C;
    if disc < 0, pts = [];
    elseif disc < 1e-12, x = -B/(2*A); pts = [x, m*x+d];
    else
        x1 = (-B+sqrt(disc))/(2*A); x2 = (-B-sqrt(disc))/(2*A);
        pts = [x1, m*x1+d; x2, m*x2+d];
    end
end
```

- [ ] **Step 8: 运行验证全部通过**

```bash
matlab -batch "cd('D:/Workspace/nest'); run('src/matlab/test/test_nest_geometry.m');"
```

预期：4/4 PASS

- [ ] **Step 9: Commit**

```bash
git add src/matlab/test/test_nest_geometry.m
git commit -m "test: add nest_geometry unit tests (4 checks)"
```

---

### Task 3: MATLAB — 重构 nest_animation.m + run_nest_demo.m → [#8]

**Files:**
- Modify: `src/matlab/nest_animation.m`
- Modify: `src/matlab/run_nest_demo.m`

- [ ] **Step 1: 重写 nest_animation.m — 函数签名和初始化**

```matlab
function nest_animation(G, ax, record_mode, fps)
% NEST_ANIMATION 三阶段鸟巢动画（含生长/延展过渡）
%   G:   几何数据（来自 nest_geometry）
%   ax:  axes 句柄
%   record_mode: false(实时) | true(录制mp4)
%   fps: 帧率 (默认18)

if nargin < 4, fps = 18; end
if nargin < 3, record_mode = false; end

dt_grow = 0.03;     % 每根立柱生长间隔 (s)
dt_rule = 0.05;     % 每条屋顶线铺出间隔 (s)
hold_t  = 0.8;      % 阶段间停顿 (s)
final_t = 2.0;      % 终态停留 (s)
```

- [ ] **Step 2: 录制辅助函数**

```matlab
    function writeFrame()
        drawnow;
        if record_mode
            writeVideo(vw, getframe(ax.Parent));
        end
    end
    function pause_or_hold(duration)
        if record_mode
            for j = 1:round(duration * fps)
                writeVideo(vw, getframe(ax.Parent));
            end
        else
            pause(duration);
        end
    end
```

- [ ] **Step 3: Stage 0 — 空坐标系**

```matlab
cla(ax); hold(ax, 'on');
view(ax, [-20, 25]);  daspect(ax, [1 1 1]);
xlim(ax, [-65, 65]);  ylim(ax, [-58, 58]);  zlim(ax, [0, 38]);
xlabel(ax, 'X');  ylabel(ax, 'Y');  zlabel(ax, 'Z');
grid(ax, 'on');

% 地面椭圆参考线
plot3(ax, G.ellipse_outer(1,:), G.ellipse_outer(2,:), zeros(1,200), ...
    'Color', [0.5 0.5 0.5], 'LineStyle', '--');
plot3(ax, G.ellipse_inner(1,:), G.ellipse_inner(2,:), zeros(1,200), ...
    'Color', [0.5 0.5 0.5], 'LineStyle', ':');
title(ax, 'Stage 0: 空坐标系');
writeFrame();  pause_or_hold(hold_t);
```

- [ ] **Step 4: Transition 0→1 — 立柱逐根生长**

```matlab
title(ax, 'Stage 1: 立柱升起');

% 预创建所有立柱句柄（零长初态）
Npillars = size(G.pillars, 1);
pillar_h = gobjects(Npillars, 1);
for i = 1:Npillars
    pillar_h(i) = plot3(ax, ...
        [G.pillars(i,1) G.pillars(i,1)], ...
        [G.pillars(i,2) G.pillars(i,2)], ...
        [0 0], 'Color', [0.75 0.75 0.75], 'LineWidth', 3);
end

% 逐根生长
for i = 1:Npillars
    z_target = G.pillars(i,4);
    n_frames = ceil(dt_grow * fps);
    for fr = 1:n_frames
        t = fr / n_frames;
        set(pillar_h(i), 'ZData', [0, t * z_target]);
        writeFrame();
    end
end
pause_or_hold(hold_t);
```

- [ ] **Step 5: Transition 1→2 — 屋顶线逐条铺出**

```matlab
title(ax, 'Stage 2: 直线构成曲面');

Nsegments = length(G.roof_segments);
roof_h = gobjects(Nsegments, 1);
for i = 1:Nsegments
    seg = G.roof_segments{i};
    roof_h(i) = plot3(ax, [seg(1,1) seg(1,1)], [seg(1,2) seg(1,2)], ...
        [seg(1,3) seg(1,3)], 'Color', [0.93 0.69 0.13], 'LineWidth', 2);
end

% 逐条延展
for i = 1:Nsegments
    seg = G.roof_segments{i};
    n_frames = ceil(dt_rule * fps);
    for fr = 1:n_frames
        t = fr / n_frames;
        set(roof_h(i), ...
            'XData', [seg(1,1), seg(1,1) + t*(seg(2,1)-seg(1,1))], ...
            'YData', [seg(1,2), seg(1,2) + t*(seg(2,2)-seg(1,2))], ...
            'ZData', [seg(1,3), seg(1,3) + t*(seg(2,3)-seg(1,3))]);
        writeFrame();
    end
end

title(ax, '鸟巢双曲抛物面直纹面');
pause_or_hold(final_t);
```

- [ ] **Step 6: 录制逻辑（仅在 record_mode 时初始化）**

```matlab
if record_mode
    mp4_path = 'out/nest.mp4';
    [mp4_dir, ~] = fileparts(mp4_path);
    if ~exist(mp4_dir, 'dir'), mkdir(mp4_dir); end
    vw = VideoWriter(mp4_path, 'MPEG-4');
    vw.FrameRate = fps;  open(vw);
end
% ... 三阶段动画 ...
if record_mode
    close(vw);  fprintf('mp4 exported: %s\n', mp4_path);
end
```

- [ ] **Step 7: 重写 run_nest_demo.m — 驱动入口**

```matlab
function run_nest_demo(record)
% RUN_NEST_DEMO 运行鸟巢双曲抛物面动画
%   run_nest_demo          % 实时动画
%   run_nest_demo(true)    % 录制 mp4

if nargin < 1, record = false; end

G = nest_geometry([]);

fig = figure('Color', 'w', 'Position', [100 100 900 700]);
ax = axes(fig);

nest_animation(G, ax, record, 18);
end
```

- [ ] **Step 8: 运行实时验证**

```bash
matlab -batch "cd('D:/Workspace/nest'); run_nest_demo(false); pause(3);"
```

预期：三阶段动画在 figure 中播放。

- [ ] **Step 9: Commit**

```bash
git add src/matlab/nest_animation.m src/matlab/run_nest_demo.m
git commit -m "feat: refactor nest_animation with 3-stage grow/extend transitions"
```

---

### Task 4: Python — 新建 nest_geometry.py 几何引擎 → [#9]

**Files:**
- Create: `src/python/nest_geometry.py`

- [ ] **Step 1: 创建文件 + 常量 + HP 函数**

```python
"""Bird's Nest hyperbolic paraboloid geometry engine."""
import numpy as np

# Global constants (prototype-verified)
AHP, BHP = 80.0, 72.0
C, Z_OFFSET = 18.0, 23.2
A_OUT, B_OUT = 60.0, 53.5
A_IN, B_IN = 34.4, 22.4
NU, NV = 50, 50
U_RANGE = (-1.06, 1.06)
V_RANGE = (-1.06, 1.06)


def hyperboloid_z(x, y):
    """HP surface height at (x, y)."""
    return C * (x**2 / AHP**2 - y**2 / BHP**2) + Z_OFFSET
```

- [ ] **Step 2: 直线与椭圆求交**

```python
def line_ellipse_intersect(m, d, a_ell, b_ell):
    """Intersection of line y = m*x + d with ellipse (x/a)^2 + (y/b)^2 = 1.
    Returns list of (x, y) tuples (0, 1, or 2 points).
    """
    A = 1/a_ell**2 + m**2/b_ell**2
    B = 2*m*d/b_ell**2
    C = d**2/b_ell**2 - 1
    disc = B**2 - 4*A*C
    if disc < 0:
        return []
    elif disc < 1e-12:
        x = -B/(2*A)
        return [(x, m*x + d)]
    else:
        sqrt_disc = np.sqrt(disc)
        x1 = (-B + sqrt_disc)/(2*A)
        x2 = (-B - sqrt_disc)/(2*A)
        return [(x1, m*x1 + d), (x2, m*x2 + d)]
```

- [ ] **Step 3: 点在椭圆内判断**

```python
def point_in_ellipse(x, y, a_ell, b_ell):
    """True if (x,y) is strictly inside the ellipse."""
    return (x**2/a_ell**2 + y**2/b_ell**2) < 1.0
```

- [ ] **Step 4: 主计算函数 `compute_geometry`**

```python
def compute_geometry():
    """Compute all nest geometry.
    Returns dict with keys: pillars, roof_segments, ellipse_outer, ellipse_inner.
    """
    pillars = []        # list of (x, y, z_base, z_top)
    roof_segments = []  # list of ((x1,y1,z1), (x2,y2,z2))

    slope_u = BHP / AHP   # +0.9
    slope_v = -BHP / AHP  # -0.9

    # --- u-family: x/AHP - y/BHP = u ---
    u_vals = np.linspace(U_RANGE[0], U_RANGE[1], NU)
    for u in u_vals:
        d = -slope_u * AHP * u
        m = slope_u
        _process_ruling(m, d, pillars, roof_segments)

    # --- v-family: x/AHP + y/BHP = v ---
    v_vals = np.linspace(V_RANGE[0], V_RANGE[1], NV)
    for v in v_vals:
        d = -slope_v * AHP * v
        m = slope_v
        _process_ruling(m, d, pillars, roof_segments)

    # ellipse outlines
    theta = np.linspace(0, 2*np.pi, 200)
    ellipse_outer = np.array([A_OUT*np.cos(theta), B_OUT*np.sin(theta)])
    ellipse_inner = np.array([A_IN*np.cos(theta), B_IN*np.sin(theta)])

    return {
        'pillars': np.array(pillars),
        'roof_segments': roof_segments,
        'ellipse_outer': ellipse_outer,
        'ellipse_inner': ellipse_inner,
    }
```

- [ ] **Step 5: 实现 `_process_ruling` 辅助函数**

```python
def _process_ruling(m, d, pillars, roof_segments):
    """Process one ruling line: intersect ellipses, connect segments."""
    pts_out = line_ellipse_intersect(m, d, A_OUT, B_OUT)
    pts_in  = line_ellipse_intersect(m, d, A_IN, B_IN)

    all_pts = []  # list of (x, y, type, t_param)
    for (x, y) in pts_out:
        all_pts.append((x, y, 1, x))  # type=1: outer
    for (x, y) in pts_in:
        all_pts.append((x, y, 2, x))  # type=2: inner

    if len(all_pts) < 2:
        return

    all_pts.sort(key=lambda p: p[3])  # sort by t_param

    for j in range(len(all_pts) - 1):
        x1, y1, t1, _ = all_pts[j]
        x2, y2, t2, _ = all_pts[j + 1]

        if t1 == 2 and t2 == 2:
            continue  # skip inner-inner

        mid_x = (x1 + x2)/2
        mid_y = (y1 + y2)/2
        if point_in_ellipse(mid_x, mid_y, A_IN, B_IN):
            continue  # segment crosses opening

        z1 = hyperboloid_z(x1, y1)
        z2 = hyperboloid_z(x2, y2)
        pillars.append((x1, y1, 0.0, z1))
        pillars.append((x2, y2, 0.0, z2))
        roof_segments.append(((x1, y1, z1), (x2, y2, z2)))
```

- [ ] **Step 6: 本地测试验证**

```bash
cd src/python && python -c "
from nest_geometry import compute_geometry, hyperboloid_z
import numpy as np
G = compute_geometry()
print(f'pillars: {len(G[\"pillars\"])}, segments: {len(G[\"roof_segments\"])}')
zs = [p[3] for p in G['pillars']]
print(f'height: [{min(zs):.1f}, {max(zs):.1f}]')
# verify midpoints
max_err = 0
for (x1,y1,z1),(x2,y2,z2) in G['roof_segments']:
    mx,my,mz = (x1+x2)/2, (y1+y2)/2, (z1+z2)/2
    max_err = max(max_err, abs(mz - hyperboloid_z(mx,my)))
print(f'max midpoint error: {max_err:.2e}')
"
```

预期：`pillars≈280, height≈[13.3, 33.3], error≈1e-15`

- [ ] **Step 7: Commit**

```bash
git add src/python/nest_geometry.py
git commit -m "feat: add Python nest geometry engine"
```

---

### Task 5: Python — 新增 test_nest_geometry.py + requirements.txt → [#10]

**Files:**
- Create: `src/python/test_nest_geometry.py`
- Create: `src/python/requirements.txt`

- [ ] **Step 1: requirements.txt**

```
numpy>=1.20
matplotlib>=3.5
pytest>=7.0
```

- [ ] **Step 2: 创建 pytest 测试文件**

```python
"""Unit tests for nest_geometry.py."""
import pytest
import numpy as np
from nest_geometry import (
    hyperboloid_z, line_ellipse_intersect,
    point_in_ellipse, compute_geometry,
    AHP, BHP, C, Z_OFFSET, A_OUT, B_OUT,
)


class TestHyperboloidZ:
    def test_at_origin(self):
        assert hyperboloid_z(0, 0) == pytest.approx(Z_OFFSET)

    def test_at_major_axis_end(self):
        z = hyperboloid_z(A_OUT, 0)
        expected = C * (A_OUT**2/AHP**2) + Z_OFFSET
        assert z == pytest.approx(expected, rel=1e-10)

    def test_at_minor_axis_end(self):
        z = hyperboloid_z(0, B_OUT)
        expected = C * (0 - B_OUT**2/BHP**2) + Z_OFFSET
        assert z == pytest.approx(expected, rel=1e-10)


class TestLineEllipseIntersect:
    def test_two_intersections(self):
        pts = line_ellipse_intersect(0, 0, A_OUT, B_OUT)
        assert len(pts) == 2
        assert abs(abs(pts[0][0]) - A_OUT) < 1e-10

    def test_no_intersection(self):
        pts = line_ellipse_intersect(0, 100, A_OUT, B_OUT)
        assert len(pts) == 0


class TestRulingMidpoints:
    def test_midpoints_on_surface(self):
        G = compute_geometry()
        errors = []
        for (x1, y1, z1), (x2, y2, z2) in G['roof_segments']:
            mx, my, mz = (x1+x2)/2, (y1+y2)/2, (z1+z2)/2
            z_surf = hyperboloid_z(mx, my)
            errors.append(abs(mz - z_surf))
        assert max(errors) < 1e-10, f"max error {max(errors):.2e}"


class TestPillars:
    def test_pillar_tops_on_surface(self):
        G = compute_geometry()
        errors = []
        for x, y, _, zt in G['pillars']:
            errors.append(abs(zt - hyperboloid_z(x, y)))
        assert max(errors) < 1e-10

    def test_min_height(self):
        G = compute_geometry()
        min_z = min(p[3] for p in G['pillars'])
        assert min_z >= 13.0, f"min height {min_z:.1f} < 13"
```

- [ ] **Step 3: 运行 pytest 验证全部通过**

```bash
cd src/python && python -m pytest test_nest_geometry.py -v
```

预期：6 passed

- [ ] **Step 4: Commit**

```bash
git add src/python/test_nest_geometry.py src/python/requirements.txt
git commit -m "test: add Python nest_geometry pytest suite + requirements"
```

---

### Task 6: Python — 新建 nest_animation.py + run_nest_demo.py → [#11]

**Files:**
- Create: `src/python/nest_animation.py`
- Create: `src/python/run_nest_demo.py`

- [ ] **Step 1: nest_animation.py — imports + 参数**

```python
"""Bird's Nest 3-stage animation using matplotlib."""
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from matplotlib.animation import FuncAnimation, FFMpegWriter
from nest_geometry import compute_geometry

AZ, EL = -20, 25
FPS = 18
DT_GROW = 0.03   # seconds per pillar
DT_RULE = 0.05   # seconds per roof segment
HOLD_T = 0.8     # pause between stages
FINAL_T = 2.0    # final hold
```

- [ ] **Step 2: 初始化 Figure + Stage 0**

```python
def run_animation(save_path=None):
    """Run 3-stage nest animation. If save_path is provided, export mp4."""
    G = compute_geometry()
    pillars = G['pillars']
    roof_segments = G['roof_segments']

    fig = plt.figure(figsize=(10, 8), facecolor='white')
    ax = fig.add_subplot(111, projection='3d')
    ax.view_init(elev=EL, azim=AZ)
    ax.set_xlim(-65, 65); ax.set_ylim(-58, 58); ax.set_zlim(0, 38)
    ax.set_xlabel('X'); ax.set_ylabel('Y'); ax.set_zlabel('Z')
    ax.set_title('Stage 0: Coordinate System')

    # ground ellipse outlines
    ax.plot(G['ellipse_outer'][0], G['ellipse_outer'][1], 0,
            '--', color='gray', linewidth=1)
    ax.plot(G['ellipse_inner'][0], G['ellipse_inner'][1], 0,
            ':', color='gray', linewidth=1)

    # pre-create pillar lines (zero-length initially)
    pillar_lines = []
    for x, y, _, _ in pillars:
        line, = ax.plot([x, x], [y, y], [0, 0],
                        color='#BFBFBF', linewidth=3)
        pillar_lines.append(line)

    # pre-create roof lines (zero-length initially)
    roof_lines = []
    for (x1, y1, z1), (x2, y2, z2) in roof_segments:
        line, = ax.plot([x1, x1], [y1, y1], [z1, z1],
                        color='#EDB120', linewidth=2)
        roof_lines.append(line)
```

- [ ] **Step 3: 动画帧生成器**

```python
    total_pillars = len(pillars)
    total_segments = len(roof_segments)
    grow_frames = int(total_pillars * DT_GROW * FPS)
    rule_frames = int(total_segments * DT_RULE * FPS)
    hold_frames = int(HOLD_T * FPS)
    final_frames = int(FINAL_T * FPS)

    def frame_generator():
        # Stage 0 hold
        for _ in range(hold_frames):
            yield

        # Transition 0->1: pillars grow
        for i in range(total_pillars):
            _, _, _, zt = pillars[i]
            nf = max(1, int(DT_GROW * FPS))
            for fr in range(nf):
                t = (fr + 1) / nf
                pillar_lines[i].set_data_3d(
                    [pillars[i][0], pillars[i][0]],
                    [pillars[i][1], pillars[i][1]],
                    [0, t * zt])
                yield
        ax.set_title('Stage 1: Pillars Complete')

        # Stage 1 hold
        for _ in range(hold_frames):
            yield

        # Transition 1->2: roof segments extend
        for i in range(total_segments):
            (x1, y1, z1), (x2, y2, z2) = roof_segments[i]
            nf = max(1, int(DT_RULE * FPS))
            for fr in range(nf):
                t = (fr + 1) / nf
                roof_lines[i].set_data_3d(
                    [x1, x1 + t*(x2-x1)],
                    [y1, y1 + t*(y2-y1)],
                    [z1, z1 + t*(z2-z1)])
                yield
        ax.set_title('Bird Nest: Hyperbolic Paraboloid Ruled Surface')

        # Final hold
        for _ in range(final_frames):
            yield
```

- [ ] **Step 4: 运行或保存**

```python
    total_frames = (hold_frames + grow_frames + hold_frames
                    + rule_frames + final_frames)

    if save_path:
        writer = FFMpegWriter(fps=FPS, bitrate=1800)
        ani = FuncAnimation(fig, lambda _: None, frames=frame_generator(),
                            save_count=total_frames)
        ani.save(save_path, writer=writer)
        print(f'MP4 saved: {save_path}')
    else:
        ani = FuncAnimation(fig, lambda _: None, frames=frame_generator(),
                            save_count=total_frames, interval=1000/FPS)
        plt.show()
```

- [ ] **Step 5: run_nest_demo.py 驱动入口**

```python
"""Driver entry point for nest animation."""
import sys
from nest_animation import run_animation

if __name__ == '__main__':
    save_path = sys.argv[1] if len(sys.argv) > 1 else None
    run_animation(save_path)
```

- [ ] **Step 6: 本地验证**

```bash
cd src/python && timeout 30 python run_nest_demo.py 2>&1 || true
```

- [ ] **Step 7: Commit**

```bash
git add src/python/nest_animation.py src/python/run_nest_demo.py
git commit -m "feat: add Python nest animation with matplotlib FuncAnimation"
```

---

### Task 7: 清理 + README → [#12]

**Files:**
- Delete: `src/matlab/prototype_geo_verify.m`
- Delete: `src/matlab/tmp/` (目录)
- Modify: `README.md`

- [ ] **Step 1: 删除原型文件**

```bash
rm src/matlab/prototype_geo_verify.m
rm -rf src/matlab/tmp/
```

- [ ] **Step 2: 更新 README.md**

```markdown
# Nest — 鸟巢双曲抛物面动画

课堂演示：用直线搭建双曲抛物面（马鞍面）。

## 数学原理

双曲抛物面方程：`z = c·(x²/ahp² − y²/bhp²) + z_offset`

利用双重直纹面特性，通过 u 族和 v 族直母线与内外椭圆求交，生成规则交叉编织网模拟鸟巢屋顶钢结构。

## 目录结构

```
src/
├── matlab/
│   ├── nest_geometry.m      几何引擎
│   ├── nest_animation.m     三阶段动画渲染
│   ├── run_nest_demo.m      驱动入口
│   └── test/
│       └── test_nest_geometry.m  单元测试
├── python/
│   ├── nest_geometry.py     几何引擎
│   ├── nest_animation.py    三阶段动画渲染
│   ├── run_nest_demo.py     驱动入口
│   ├── test_nest_geometry.py pytest单元测试
│   └── requirements.txt     依赖清单
docs/
├── superpowers/
│   ├── specs/2026-06-19-nest-iteration2-design.md  设计规格
│   ├── prd/nest-iteration2-prd.md                  产品需求
│   └── plans/2026-06-19-nest-iteration2-plan.md    实现计划
```

## 运行

### MATLAB

```matlab
run_nest_demo           % 实时动画
run_nest_demo(true)     % 录制 mp4
```

### Python

```bash
cd src/python
pip install -r requirements.txt
python run_nest_demo.py              # 实时动画
python run_nest_demo.py out/nest.mp4 # 导出 mp4
```

## 测试

```matlab
run('src/matlab/test/test_nest_geometry.m')
```

```bash
cd src/python && pytest test_nest_geometry.py -v
```

## 参数

| 参数 | 值 | 说明 |
|------|-----|------|
| ahp, bhp | 80, 72 | HP曲面参数 |
| c, z_offset | 18, 23.2 | 翘起量，垂直偏移 |
| a_out, b_out | 60, 53.5 | 外椭圆（外壳） |
| a_in, b_in | 34.4, 22.4 | 内椭圆（开口） |
| 直母线 | u族50 + v族50 | u,v∈[-1.06,1.06] |
| 相机 | az=-20°, el=25° | 侧俯视 |
```

- [ ] **Step 3: Commit**

```bash
git add README.md && git rm src/matlab/prototype_geo_verify.m
git rm -r src/matlab/tmp/
git commit -m "chore: remove prototype, update README with run and test instructions"
```

---

## 并行执行建议

```
Wave 1 (并行):  Task 1 (MATLAB Geometry)  ∥  Task 4 (Python Geometry)
Wave 2 (并行):  Task 2 (MATLAB Tests)     ∥  Task 5 (Python Tests)
Wave 3 (并行):  Task 3 (MATLAB Animation) ∥  Task 6 (Python Animation)  
Wave 4:         Task 7 (Cleanup)
```

每波内可并行 dispatch subagent，波间有依赖（需上一波完成）。

---

> **下一步**: 使用 `superpowers:subagent-driven-development` 或 `superpowers:executing-plans` 按 Task 顺序执行，checkbox 追踪进度。
