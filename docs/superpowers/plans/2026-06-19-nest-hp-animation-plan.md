# 鸟巢双曲抛物面动画 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 MATLAB 多阶段 3D 动画，以鸟巢椭圆环立柱 + 双曲抛物面直纹母线为载体，课堂演示「用直线搭建马鞍面」。

**Architecture:** 4 个模块（geometry → animation → driver → tests），分 4 个 tracer-bullet Issues（#2→#3→#4，#5 独立）。每个 Issue 均有独立可验证的成果。

**Tech Stack:** MATLAB R2021b, VideoWriter (MPEG-4), rgb2ind (gif)

**关联文档:**
- Spec: `docs/superpowers/specs/2026-06-19-nest-hp-animation-design.md`
- PRD: `docs/superpowers/prd/nest-hp-animation-prd.md` + GitHub Issue #1
- Issues: #2 (几何+测试), #3 (动画), #4 (导出), #5 (README)
- 设计稿: `designs/nest-hp-animation/Nest Animation Design.html`
- 术语表: `CONTEXT.md`

---

## 依赖关系图

```
#2 (Geometry + Tests) ──blocking──▶ #3 (Animation) ──blocking──▶ #4 (Export)

#5 (README) ──建议在 #2+#3+#4 完成后执行（需引用最终代码结构）
```

- **#2 → #3**：强依赖。#3 调用 `nest_geometry` 获取所有几何数据。
- **#3 → #4**：强依赖。#4 在 #3 的动画循环中插入录制逻辑。
- **#5**：无代码依赖，但与 #2/#3/#4 有文档交叉引用关系。建议最后执行以确保文档与最终代码一致。

> 并行：无。本项目仅 3 个代码文件 + 1 个测试文件，依赖串行清晰，不需要并行 agent。

---

## 文件结构（最终态）

```
nest/
├── CONTEXT.md                          # 领域术语表（已存在）
├── README.md                           # 项目说明（#5 创建）
├── .gitignore                          # 忽略 .superpowers/ out/ *.asv（已存在）
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-06-19-nest-hp-animation-design.md  # 设计规范（已存在）
│       └── plans/
│           └── 2026-06-19-nest-hp-animation-plan.md    # 本文件
├── designs/
│   └── nest-hp-animation/
│       └── Nest Animation Design.html  # 3D 预览设计稿（已存在）
├── src/
│   └── matlab/
│       ├── nest_geometry.m             # 纯几何计算（#2 创建）
│       ├── nest_animation.m            # 三阶段动画（#3 创建）
│       ├── run_nest_demo.m             # 驱动+录制（#3 创建，#4 修改）
│       └── test/
│           └── test_nest_geometry.m    # 单元测试（#2 创建）
└── out/                                # 产物目录（#4 产出）
    ├── nest.mp4
    └── nest.gif
```

---

## Issue #2: 几何模块 + 单元测试

> GitHub: https://github.com/shanhuyuli/nest/issues/2
> 阻塞于：无（直接开始）
> 阻塞：Issue #3, Issue #4

### Task 2.0: 创建目录结构

- [ ] **Step 2.0.1: 创建 src/matlab/test 目录**

```bash
mkdir -p src/matlab/test
```

- [ ] **Step 2.0.2: Commit**

```bash
git add src/
git commit -m "chore: create MATLAB source directory structure"
```

### Task 2.1: 编写 nest_geometry.m

**Files:** Create `src/matlab/nest_geometry.m`

- [ ] **Step 2.1.1: 编写函数签名与参数默认值**

```matlab
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
```

- [ ] **Step 2.1.2: 编写立柱坐标计算**

```matlab
% 立柱沿椭圆环均匀分布
theta = linspace(0, 2*pi, p.N+1);
theta = theta(1:p.N);  % 去掉闭合重复点 (θ=0 与 θ=2π)

% 辅助函数：曲面 z 值
hpz = @(x, y) p.c * (x.^2/p.a^2 - y.^2/p.b^2);

x_p = p.a * cos(theta);
y_p = p.b * sin(theta);
z_p = hpz(x_p, y_p);  % 柱顶贴合曲面
G.pillars = [x_p; y_p; z_p];  % 3×N 矩阵
```

- [ ] **Step 2.1.3: 编写母线端点计算**

```matlab
% uv 域 → xy 域映射（规范化标度）
uv2xy = @(u, v) deal(p.a*(u+v)/2, p.b*(v-u)/2);
uv2z  = @(u, v) p.c * u * v;

% u=const 组母线（v 从 -1 到 1）
G.rule_u = cell(1, p.M_u - 1);
for k = 1:(p.M_u - 1)
    u = -1 + 2*k/p.M_u;  % 跳过 u=-1 边界
    [x1, y1] = uv2xy(u, -1); z1 = uv2z(u, -1);
    [x2, y2] = uv2xy(u,  1); z2 = uv2z(u,  1);
    G.rule_u{k} = [x1 x2; y1 y2; z1 z2];  % 3×2：两端点
end

% v=const 组母线（u 从 -1 到 1）
G.rule_v = cell(1, p.M_v - 1);
for k = 1:(p.M_v - 1)
    v = -1 + 2*k/p.M_v;  % 跳过 v=-1 边界
    [x1, y1] = uv2xy(-1, v); z1 = uv2z(-1, v);
    [x2, y2] = uv2xy( 1, v); z2 = uv2z( 1, v);
    G.rule_v{k} = [x1 x2; y1 y2; z1 z2];
end
```

- [ ] **Step 2.1.4: 编写曲面网格与椭圆环**

```matlab
% 曲面网格（供 surf 半透明面片）
[xg, yg] = meshgrid(linspace(-p.a, p.a, 30), linspace(-p.b, p.b, 30));
zg = hpz(xg, yg);
G.surf_mesh = struct('X', xg, 'Y', yg, 'Z', zg);

% 椭圆地面环采样（供 plot3 地面环）
ell_theta = linspace(0, 2*pi, 200);
G.ellipse_pts = [p.a * cos(ell_theta); p.b * sin(ell_theta)];
```

- [ ] **Step 2.1.5: 验证几何函数可运行**

在 MATLAB 中执行：
```matlab
cd src/matlab
p = struct('a',6,'b',5,'c',2.5,'N',10,'M_u',9,'M_v',9);
G = nest_geometry(p);
assert(size(G.pillars,2) == 10, 'Pillar count mismatch');
assert(length(G.rule_u) == 8, 'Rule-u count mismatch');
assert(length(G.rule_v) == 8, 'Rule-v count mismatch');
disp('nest_geometry 基本功能验证通过');
```

- [ ] **Step 2.1.6: Commit**

```bash
git add src/matlab/nest_geometry.m
git commit -m "feat: add nest_geometry pure function module"
```

### Task 2.2: 编写 test_nest_geometry.m（TDD 方式）

**Files:** Create `src/matlab/test/test_nest_geometry.m`

- [ ] **Step 2.2.1: 编写 TC1 — 母线中点在曲面上**

```matlab
%% test_nest_geometry — 鸟巢几何单元测试套件
% 运行: runtests('test_nest_geometry')

function tests = test_nest_geometry
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.p = struct('a',6,'b',5,'c',2.5,'N',10,'M_u',9,'M_v',9);
    testCase.TestData.G = nest_geometry(testCase.TestData.p);
end

%% TC1: 母线中点在曲面上（证明线段是直线）
function testRulingMidpointOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    
    for k = 1:length(G.rule_u)
        d = G.rule_u{k};
        M = (d(:,1) + d(:,2)) / 2;
        z_expected = hpz(M(1), M(2));
        verifyEqual(testCase, M(3), z_expected, 'AbsTol', 1e-10);
    end
    for k = 1:length(G.rule_v)
        d = G.rule_v{k};
        M = (d(:,1) + d(:,2)) / 2;
        z_expected = hpz(M(1), M(2));
        verifyEqual(testCase, M(3), z_expected, 'AbsTol', 1e-10);
    end
end
```

- [ ] **Step 2.2.2: 运行 TC1 验证通过**

```matlab
result = runtests('test_nest_geometry', 'ProcedureName', 'testRulingMidpointOnSurface');
assert(all([result.Passed]));
disp('TC1 通过');
```

- [ ] **Step 2.2.3: 编写 TC2 — 立柱在椭圆上**

```matlab
%% TC2: 立柱在椭圆上
function testPillarsOnEllipse(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    for i = 1:p.N
        r = (G.pillars(1,i)/p.a)^2 + (G.pillars(2,i)/p.b)^2;
        verifyEqual(testCase, r, 1, 'AbsTol', 1e-10);
    end
end
```

- [ ] **Step 2.2.4: 运行 TC2 验证通过**

```matlab
result = runtests('test_nest_geometry', 'ProcedureName', 'testPillarsOnEllipse');
assert(all([result.Passed]));
```

- [ ] **Step 2.2.5: 编写 TC3 — 柱顶贴合曲面**

```matlab
%% TC3: 柱顶贴合曲面
function testPillarTopOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    for i = 1:p.N
        z_expected = hpz(G.pillars(1,i), G.pillars(2,i));
        verifyEqual(testCase, G.pillars(3,i), z_expected, 'AbsTol', 1e-10);
    end
end
```

- [ ] **Step 2.2.6: 编写 TC4/TC5 — 母线全段在曲面上（插值点验证）**

```matlab
%% TC4: u=const 母线全段在曲面上（取 t=0.25, 0.75 插值点）
function testRulingU_FullOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    for k = 1:length(G.rule_u)
        d = G.rule_u{k};
        for t = [0.25, 0.75]
            P = d(:,1) + t * (d(:,2) - d(:,1));
            z_expected = hpz(P(1), P(2));
            verifyEqual(testCase, P(3), z_expected, 'AbsTol', 1e-10);
        end
    end
end

%% TC5: v=const 母线全段在曲面上
function testRulingV_FullOnSurface(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    hpz = @(x,y) p.c*(x.^2/p.a^2 - y.^2/p.b^2);
    for k = 1:length(G.rule_v)
        d = G.rule_v{k};
        for t = [0.25, 0.75]
            P = d(:,1) + t * (d(:,2) - d(:,1));
            z_expected = hpz(P(1), P(2));
            verifyEqual(testCase, P(3), z_expected, 'AbsTol', 1e-10);
        end
    end
end
```

- [ ] **Step 2.2.7: 编写 TC6 — 非法参数抛错**

```matlab
%% TC6: 非法参数抛错
function testInvalidParams(testCase)
    verifyError(testCase, @() nest_geometry(struct('a',6,'b',5,'c',2.5,'N',2,'M_u',9,'M_v',9)), 'NEST:pillarCount');
    verifyError(testCase, @() nest_geometry(struct('a',0,'b',5,'c',2.5,'N',10,'M_u',9,'M_v',9)), 'NEST:ellipseAxis');
end
```

- [ ] **Step 2.2.8: 编写 TC7 — 曲面网格覆盖椭圆域**

```matlab
%% TC7: 曲面网格覆盖椭圆域
function testSurfMeshCoversDomain(testCase)
    G = testCase.TestData.G;
    p = testCase.TestData.p;
    verifyTrue(testCase, min(G.surf_mesh.X(:)) <= -p.a + 0.1);
    verifyTrue(testCase, max(G.surf_mesh.X(:)) >=  p.a - 0.1);
    verifyTrue(testCase, min(G.surf_mesh.Y(:)) <= -p.b + 0.1);
    verifyTrue(testCase, max(G.surf_mesh.Y(:)) >=  p.b - 0.1);
end
```

- [ ] **Step 2.2.9: 运行全量测试套件**

```matlab
result = runtests('test_nest_geometry');
disp(result);
assert(all([result.Passed]), '有测试未通过！');
```

Expected: 7 项全部 PASS。

- [ ] **Step 2.2.10: Commit**

```bash
git add src/matlab/test/test_nest_geometry.m
git commit -m "test: add nest_geometry unit tests (7 test cases)"
```

### Issue #2 验收检查

- [ ] `test_nest_geometry` 7/7 通过
- [ ] `nest_geometry` 为纯函数（不创建 figure/axes）
- [ ] 参数可集中修改

---

## Issue #3: 三阶段动画（含生长/延展）

> GitHub: https://github.com/shanhuyuli/nest/issues/3
> 阻塞于：Issue #2
> 阻塞：Issue #4

### Task 3.1: 编写 nest_animation.m

**Files:** Create `src/matlab/nest_animation.m`

- [ ] **Step 3.1.1: 编写函数签名与阶段 0（空坐标系）**

```matlab
function nest_animation(G, p, ax, recorder)
% NEST_ANIMATION 三阶段鸟巢动画（含生长/延展）
%   G:          几何数据（来自 nest_geometry）
%   p:          参数字典（含视觉/动画参数）
%   ax:         axes 句柄
%   recorder:   VideoWriter 句柄（可选，为空时仅实时显示）

% 阶段 0：空坐标系
title(ax, '');
cla(ax); hold(ax, 'on');
view(ax, [p.az, p.el]); axis(ax, 'equal');
xlim(ax, [-p.a-1, p.a+1]); ylim(ax, [-p.b-1, p.b+1]); zlim(ax, [-2*p.c, 2*p.c]);
xlabel(ax, 'x'); ylabel(ax, 'y'); zlabel(ax, 'z');
grid(ax, 'on'); box(ax, 'on');

% 椭圆地面环
ell = G.ellipse_pts;
plot3(ax, ell(1,:), ell(2,:), zeros(1,200), 'Color', [0.5 0.5 0.5]);
drawnow; pause(p.hold_t);
```

- [ ] **Step 3.1.2: 编写阶段 1 — 蓝立柱生长动画**

```matlab
% 阶段 1：立柱生长
title(ax, '\color{black}阶段1：立柱升起');

pillar_h = gobjects(1, p.N);
for i = 1:p.N
    pillar_h(i) = plot3(ax, [G.pillars(1,i) G.pillars(1,i)], ...
                            [G.pillars(2,i) G.pillars(2,i)], ...
                            [0 0], ...
                            'Color', [0 114 189]/255, 'LineWidth', 2);
end

for i = 1:p.N
    z_target = G.pillars(3,i);
    for frm = 1:p.n_pillar
        t = frm / p.n_pillar;
        set(pillar_h(i), 'ZData', [0, t * z_target]);
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        end
    end
    pause(p.dt);  % 每根完成后停顿
end
```

- [ ] **Step 3.1.3: 编写阶段 2 — 曲面片 + 母线延展动画**

```matlab
% 阶段 2：曲面片 + 母线
title(ax, '\color{black}阶段2：直线构成曲面');
pause(p.hold_t * 0.5);

% 半透明曲面片
surf(ax, G.surf_mesh.X, G.surf_mesh.Y, G.surf_mesh.Z, ...
    'FaceAlpha', p.alpha_surf, 'EdgeColor', 'none', ...
    'FaceColor', [237 177 32]/255);
drawnow;

% u=const 组母线（#EDB120）
rule_uh = gobjects(1, length(G.rule_u));
for k = 1:length(G.rule_u)
    d = G.rule_u{k};
    % 零长初态（起点=终点）
    rule_uh(k) = plot3(ax, [d(1,1) d(1,1)], [d(2,1) d(2,1)], [d(3,1) d(3,1)], ...
        'Color', [237 177 32]/255, 'LineWidth', 1.5);
end
drawnow;  % 刷新隐藏零长线

for k = 1:length(G.rule_u)
    d = G.rule_u{k};
    xs = d(1,1); ys = d(2,1); zs = d(3,1);
    xe = d(1,2); ye = d(2,2); ze = d(3,2);
    for frm = 1:p.n_rule
        t = frm / p.n_rule;
        set(rule_uh(k), ...
            'XData', [xs, xs + t*(xe-xs)], ...
            'YData', [ys, ys + t*(ye-ys)], ...
            'ZData', [zs, zs + t*(ze-zs)]);
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        end
    end
    pause(p.dt);
end

% v=const 组母线（#FFD060）
rule_vh = gobjects(1, length(G.rule_v));
for k = 1:length(G.rule_v)
    d = G.rule_v{k};
    rule_vh(k) = plot3(ax, [d(1,1) d(1,1)], [d(2,1) d(2,1)], [d(3,1) d(3,1)], ...
        'Color', [255 208 96]/255, 'LineWidth', 1.5);
end
drawnow;

for k = 1:length(G.rule_v)
    d = G.rule_v{k};
    xs = d(1,1); ys = d(2,1); zs = d(3,1);
    xe = d(1,2); ye = d(2,2); ze = d(3,2);
    for frm = 1:p.n_rule
        t = frm / p.n_rule;
        set(rule_vh(k), ...
            'XData', [xs, xs + t*(xe-xs)], ...
            'YData', [ys, ys + t*(ye-ys)], ...
            'ZData', [zs, zs + t*(ze-zs)]);
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        end
    end
    pause(p.dt);
end

% 终态停留
pause(1.5);
end
```

- [ ] **Step 3.1.4: Commit**

```bash
git add src/matlab/nest_animation.m
git commit -m "feat: add three-stage animation with growth/extension"
```

### Task 3.2: 编写 run_nest_demo.m（实时模式）

**Files:** Create `src/matlab/run_nest_demo.m`

- [ ] **Step 3.2.1: 编写驱动脚本**

```matlab
function run_nest_demo(varargin)
% RUN_NEST_DEMO 运行鸟巢双曲抛物面动画
%
% 用法:
%   run_nest_demo                          % 实时动画（不录制）
%   run_nest_demo('record', true)          % 录制 mp4
%   run_nest_demo('record', true, 'gif', true)  % 录制 mp4 + gif
%   run_nest_demo('record', true, 'out', 'custom.mp4')
%
% 名称-值对参数:
%   'record'  - false(默认) | true    是否录制 mp4
%   'gif'     - false(默认) | true    是否导出 gif
%   'out'     - 输出路径（默认 'out/nest.mp4'）
%   'params'  - 参数字典结构体（覆盖默认值）

% 解析参数
opts = parse_args(varargin{:});

% 构建默认参数
p = struct(...
    'a', 6, 'b', 5, 'c', 2.5, 'N', 10, ...
    'M_u', 9, 'M_v', 9, ...
    'az', -35, 'el', 30, ...
    'n_pillar', 8, 'n_rule', 10, ...
    'dt', 0.15, 'hold_t', 0.8, ...
    'fps', 30, 'alpha_surf', 0.2);

% 覆盖用户参数
if isfield(opts, 'params') && isstruct(opts.params)
    fns = fieldnames(opts.params);
    for i = 1:length(fns)
        p.(fns{i}) = opts.params.(fns{i});
    end
end

% 计算几何
G = nest_geometry(p);

% 创建图窗
fig = figure('Color', 'w', 'Position', [100 100 900 700]);
ax = axes(fig);

% 录制逻辑（#4 会扩展此部分）
if opts.record
    mp4_path = opts.out;
    [mp4_dir, ~] = fileparts(mp4_path);
    if ~exist(mp4_dir, 'dir'), mkdir(mp4_dir); end
    vw = VideoWriter(mp4_path, 'MPEG-4');
    vw.FrameRate = p.fps;
    open(vw);
    nest_animation(G, p, ax, vw);
    close(vw);
    fprintf('mp4 已导出: %s\n', mp4_path);
    
    if opts.gif
        % 将在 #4 中扩展 gif 导出逻辑
        fprintf('gif 导出将在 Issue #4 中实现。\n');
    end
else
    nest_animation(G, p, ax, []);
end
end

function opts = parse_args(varargin)
    opts = struct('record', false, 'gif', false, 'out', 'out/nest.mp4');
    i = 1;
    while i <= length(varargin)
        if strcmpi(varargin{i}, 'record')
            opts.record = logical(varargin{i+1}); i = i+2;
        elseif strcmpi(varargin{i}, 'gif')
            opts.gif = logical(varargin{i+1}); i = i+2;
        elseif strcmpi(varargin{i}, 'out')
            opts.out = varargin{i+1}; i = i+2;
        else
            i = i+1;
        end
    end
end
```

- [ ] **Step 3.2.2: 验证实时动画运行**

在 MATLAB 中执行：
```matlab
cd src/matlab
run_nest_demo();  % 应显示完整三阶段动画
```

人工验收：
- [ ] 阶段 0 显示椭圆地面环 + 三轴标注
- [ ] 阶段 1 逆时针逐根蓝柱生长
- [ ] 阶段 2 半透明曲面片 + u 组橙线延展 + v 组浅橙线延展
- [ ] 视角 az=-35, el=30，侧面俯视
- [ ] 无句柄错误

- [ ] **Step 3.2.3: Commit**

```bash
git add src/matlab/run_nest_demo.m
git commit -m "feat: add run_nest_demo driver script (live mode)"
```

### Issue #3 验收检查

- [ ] `run_nest_demo()` 显示完整三阶段动画
- [ ] 所有视觉规范正确（颜色、线宽、视角、标题）
- [ ] 生长/延展动画流畅，无「先全出现再消失」

---

## Issue #4: mp4/gif 导出

> GitHub: https://github.com/shanhuyuli/nest/issues/4
> 阻塞于：Issue #3
> 阻塞：无（最后环节）

### Task 4.1: 扩展 run_nest_demo.m 以支持 gif 导出

**Files:** Modify `src/matlab/run_nest_demo.m`

> 注意：gif 采集需嵌入 `nest_animation` 的帧循环中。最简单的方式是：先录制 mp4（已在动画中逐帧 writeVideo），录完后从 mp4 读取帧转 gif。但更高效的方式是改造 nest_animation 使其接收 gif 采集回调函数。

**决策**：为保持模块简洁，采用「mp4 录制后再转 gif」的方式。在 `run_nest_demo` 中 mp4 录制完后，用 `readFrame` 逐帧回读转 gif。这避免了污染 `nest_animation` 的接口。

- [ ] **Step 4.1.1: 修改 run_nest_demo.m — 添加 gif 录制逻辑**

修改录制部分，在 mp4 录制完成后追加 gif 转换：

```matlab
% 录制逻辑（替换原有录制块）
if opts.record
    mp4_path = opts.out;
    [mp4_dir, ~] = fileparts(mp4_path);
    if ~exist(mp4_dir, 'dir'), mkdir(mp4_dir); end
    
    vw = VideoWriter(mp4_path, 'MPEG-4');
    vw.FrameRate = p.fps;
    open(vw);
    nest_animation(G, p, ax, vw);
    close(vw);
    fprintf('mp4 已导出: %s\n', mp4_path);
    
    if opts.gif
        gif_path = [mp4_path(1:end-4) '.gif'];
        mp4_to_gif(mp4_path, gif_path, p.fps);
        fprintf('gif 已导出: %s\n', gif_path);
    end
else
    nest_animation(G, p, ax, []);
end
```

- [ ] **Step 4.1.2: 编写 mp4_to_gif 辅助函数**

在 `run_nest_demo.m` 末尾添加局部函数：

```matlab
function mp4_to_gif(mp4_path, gif_path, fps)
% MP4_TO_GIF 从 mp4 文件逐帧读取并转为 gif
    vr = VideoReader(mp4_path);
    delay = 1 / fps;
    first = true;
    while hasFrame(vr)
        frame = readFrame(vr);
        [im, map] = rgb2ind(frame, 256, 'nodither');
        if first
            imwrite(im, map, gif_path, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
            first = false;
        else
            imwrite(im, map, gif_path, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
        end
    end
end
```

- [ ] **Step 4.1.3: 验证录制功能**

在 MATLAB 中执行：
```matlab
cd src/matlab
run_nest_demo('record', true, 'gif', true);
```

检查：
- [ ] `out/nest.mp4` 生成且可播放
- [ ] `out/nest.gif` 生成且可播放
- [ ] mp4 中半透明曲面可见
- [ ] gif 中橙色（#EDB120/#FFD060）可辨

- [ ] **Step 4.1.4: Commit**

```bash
git add src/matlab/run_nest_demo.m
git commit -m "feat: add mp4/gif export with mp4-to-gif conversion"
```

### Issue #4 验收检查

- [ ] `out/nest.mp4` 系统播放器可播放
- [ ] `out/nest.gif` 可播放，橙色可辨
- [ ] mp4 中动画逐根节奏清晰
- [ ] gif 自动循环

---

## Issue #5: README 文档

> GitHub: https://github.com/shanhuyuli/nest/issues/5
> 阻塞于：无（但建议在 #2/#3/#4 完成后执行）
> 阻塞：无

### Task 5.1: 编写 README.md

**Files:** Create `README.md`（仓库根目录）

- [ ] **Step 5.1.1: 编写 README.md**

```markdown
# 🏟️ 鸟巢双曲抛物面动画 — Nest HP Animation

课堂演示：用直线搭建双曲抛物面（马鞍面）。以鸟巢（国家体育场）为载体的 MATLAB 多阶段 3D 动画。

## 环境要求

- Windows 10 或更高版本
- MATLAB R2021b 或更高版本

## 快速开始

### 实时动画

1. 打开 MATLAB，切换到 `src/matlab/` 目录。
2. 在命令窗口运行：

```matlab
run_nest_demo
```

3. 动画将分三阶段自动播放：
   - **阶段 0**：空坐标系（椭圆地面环 + 三轴标注）
   - **阶段 1**：蓝色立柱逐根逆时针升起（生长动画）
   - **阶段 2**：橙色直纹母线逐条延展，勾勒出双曲抛物面

### 导出视频

```matlab
% 导出 mp4 + gif
run_nest_demo('record', true, 'gif', true)

% 仅导出 mp4
run_nest_demo('record', true)

% 自定义输出路径
run_nest_demo('record', true, 'out', 'my_nest.mp4')
```

产物位于 `out/` 目录：
- `out/nest.mp4` — 视频（H.264 MPEG-4）
- `out/nest.gif` — 动画（256 色，可嵌入 PPT）

## 修改参数

编辑 `src/matlab/run_nest_demo.m` 中的默认参数块：

```matlab
p = struct(...
    'a', 6,     ... % 椭圆长半轴
    'b', 5,     ... % 椭圆短半轴
    'c', 2.5,   ... % 翘起量
    'N', 10,    ... % 立柱数量
    'M_u', 9,   ... % u=const 母线条数
    'M_v', 9);  ... % v=const 母线条数
```

## 文件结构

```
src/matlab/
├── nest_geometry.m        # 纯几何计算（立柱坐标、母线端点、曲面网格）
├── nest_animation.m       # 三阶段动画（生长/延展 + 逐帧渲染）
├── run_nest_demo.m        # 驱动入口 + mp4/gif 导出
└── test/
    └── test_nest_geometry.m  # 单元测试（7 项）
```

## 设计文档

- [设计规范](docs/superpowers/specs/2026-06-19-nest-hp-animation-design.md)
- [PRD (#1)](https://github.com/shanhuyuli/nest/issues/1)
- [领域术语表](CONTEXT.md)
- [3D 可视化设计稿](designs/nest-hp-animation/Nest Animation Design.html) — 浏览器打开预览

## 许可证

MIT
```

- [ ] **Step 5.1.2: 验证交叉引用链接**

在 GitHub 上打开 README，验证所有链接可正确跳转。

- [ ] **Step 5.1.3: Commit**

```bash
git add README.md
git commit -m "docs: add README with setup instructions and project overview"
```

### Issue #5 验收检查

- [ ] README 包含项目简介、环境要求、运行方式
- [ ] 所有链接正确（spec、PRD、CONTEXT.md、Issues）
- [ ] 新手可按 README 成功运行动画

---

## 最终集成检查

所有 Issues 完成后，执行全流程验证：

- [ ] **Step F.1: 运行全量测试**

```matlab
cd src/matlab
result = runtests('test/test_nest_geometry');
assert(all([result.Passed]), '测试未通过！');
disp('7/7 测试通过');
```

- [ ] **Step F.2: 运行实时动画**

```matlab
run_nest_demo();  % 人工视觉验收
```

- [ ] **Step F.3: 运行录制导出**

```matlab
run_nest_demo('record', true, 'gif', true);
% 检查 out/nest.mp4 和 out/nest.gif
```

- [ ] **Step F.4: 推送到远程**

```bash
git push origin main
```

---

## 计划自我审查

### 1. Spec 覆盖检查

| Spec 章节 | 对应任务 |
|-----------|----------|
| §4 核心数学（双重直纹证明） | Task 2.1（geometry 实现 + 母线两端点定义） |
| §4.5 柱顶贴合曲面 | Task 2.1.2 + TC3（单元测试验证） |
| §5 几何参数 | Task 3.2.1（参数默认值） |
| §6.1 nest_geometry.m 接口 | Task 2.1（完整实现） |
| §6.2 nest_animation.m 接口 | Task 3.1（完整实现，含生长/延展） |
| §6.3 run_nest_demo.m 接口 | Task 3.2 + Task 4.1（驱动+录制） |
| §6.4 test_nest_geometry.m | Task 2.2（7 项测试） |
| §7 视觉规范 | Task 3.1（颜色/线宽/alpha） |
| §8 动画时序 | Task 3.1（pause 间隔） |
| §9 错误处理 | Task 2.1.1（参数校验） + TC6 |
| §11 验收标准 | 各 Issue 验收 + 最终集成检查 |
| §12 文件清单 | 文件结构表（全部覆盖） |
| Grill 决议（12 项） | 分散在各 Task 的实现细节中 |
| Prototype 验证（3 项） | Task 2/3/4 的具体实现已吸收原型结论 |

**未发现遗漏。**

### 2. 占位符扫描

搜索以下模式：
- "TBD" / "TODO": 无
- "implement later" / "fill in details": 无
- "add error handling"（无代码）: 无
- "类似前文" / "{相似}": 无
- 没有代码块的操作步骤: 无（所有步骤均有代码或命令）

### 3. 类型一致性

- `G.pillars`: [3×N] 矩阵 — Task 2.1.2 定义，Task 3.1.2 使用 ✓
- `G.rule_u` / `G.rule_v`: cell {3×2} — Task 2.1.3 定义，Task 3.1.3 使用 ✓
- `G.surf_mesh`: struct(X,Y,Z) — Task 2.1.4 定义，Task 3.1.3 使用 ✓
- `G.ellipse_pts`: [2×200] — Task 2.1.4 定义，Task 3.1.1 使用 ✓
- 参数结构体 `p`: 字段一致（a, b, c, N, M_u, M_v, az, el, n_pillar, n_rule, dt, hold_t, fps, alpha_surf）✓
