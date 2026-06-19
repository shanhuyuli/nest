# 🏟️ 鸟巢双曲抛物面动画 — Nest HP Animation

课堂演示：用直线搭建双曲抛物面（马鞍面）。以鸟巢（国家体育场）为载体的 MATLAB 多阶段 3D 动画。

## 动画预览

```text
阶段 0: 空坐标系        阶段 1: 蓝立柱升起      阶段 2: 橙母线铺出
(椭圆环 + 三轴)        (逆时针逐根生长)        (先u组后v组延展)
```

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
   - **阶段 1**：蓝色立柱逐根逆时针升起（生长动画，约 2 秒）
   - **阶段 2**：橙色直纹母线逐条延展（先 u=const 组后 v=const 组），勾勒出双曲抛物面

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
- `out/nest.mp4` — 视频（H.264 MPEG-4，约 560 KB）
- `out/nest.gif` — 动画（256 色，可嵌入 PPT）

### 运行测试

```matlab
cd src/matlab
result = runtests('test/test_nest_geometry');
disp(result);  % 7/7 通过
```

## 修改参数

编辑 `run_nest_demo.m` 中的默认参数块，或传入 `params` 结构体：

```matlab
% 方式 1：修改 run_nest_demo.m 中的默认参数
p = struct(...
    'a', 6,     ... % 椭圆长半轴（默认 6）
    'b', 5,     ... % 椭圆短半轴（默认 5，比例 1.2）
    'c', 2.5,   ... % 翘起量（控制马鞍起伏）
    'N', 10,    ... % 立柱数量
    'M_u', 9,   ... % u=const 母线条数
    'M_v', 9);  ... % v=const 母线条数

% 方式 2：运行时传入
custom_p = struct('N', 16, 'c', 3.0);
run_nest_demo('params', custom_p);
```

## 文件结构

```
src/matlab/
├── nest_geometry.m            # 纯几何计算（立柱坐标、母线端点、曲面网格）
├── nest_animation.m           # 三阶段动画（生长/延展 + 逐帧渲染）
├── run_nest_demo.m            # 驱动入口 + mp4/gif 导出
└── test/
    └── test_nest_geometry.m   # 单元测试（7 项）
out/
├── nest.mp4                   # 导出视频
└── nest.gif                   # 导出 gif（循环播放）
```

## 核心数学

**双曲抛物面方程**：`z = c·(x²/a² − y²/b²)`

- 参数化：`x = a(u+v)/2`, `y = b(v−u)/2`, `z = c·u·v`（`u,v ∈ [−1,1]`）
- 固定 `u = u₀`：`z = c·u₀·v` → 随 v 线性变化 → **一条直线**
- 固定 `v = v₀`：`z = c·v₀·u` → 随 u 线性变化 → **另一条直线**
- 双重直纹面：过曲面上每一点恰有两条直线

## 设计文档

- [设计规范](docs/superpowers/specs/2026-06-19-nest-hp-animation-design.md)
- [PRD (#1)](https://github.com/shanhuyuli/nest/issues/1)
- [实施计划](docs/superpowers/plans/2026-06-19-nest-hp-animation-plan.md)
- [领域术语表](CONTEXT.md)
- [3D 可视化设计稿](designs/nest-hp-animation/Nest Animation Design.html) — 浏览器打开预览

## 许可证

MIT
