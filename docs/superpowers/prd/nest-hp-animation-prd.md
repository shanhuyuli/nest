# PRD: 鸟巢双曲抛物面动画 — 迭代 1

- **日期**: 2026-06-19
- **状态**: Ready for Implementation
- **关联 Spec**: `docs/superpowers/specs/2026-06-19-nest-hyperbolic-paraboloid-animation-design.md`
- **关联设计稿**: `designs/nest-hp-animation/Nest Animation Design.html`

---

## Problem Statement

教师在课堂讲授「双曲抛物面是双重直纹面」时，缺乏直观的可视化演示工具。学生难以从静态公式和图解理解「过曲面上每一点恰有两条直线」这一核心数学事实。需要一段以真实建筑（鸟巢/国家体育场）为载体的动画，展示**立柱支撑 + 直纹母线搭建马鞍面屋顶**的完整过程。

## Solution

开发一段 MATLAB 多阶段 3D 动画：

1. **阶段 0**：展示空坐标系，建立空间参照；
2. **阶段 1**：沿椭圆环逐根升起蓝色立柱，每根以**生长动画**从地面升至目标高度，柱顶贴合双曲抛物面；
3. **阶段 2**：先显示半透明曲面片，再逐条延展出两组橙色直纹母线（先 u=const 组后 v=const 组），以**延展动画**从参数负端向正端铺开。

动画提供两种交付形态：
- **实时脚本**：MATLAB 中一键运行，课堂现场演示；
- **mp4 + gif**：脱离 MATLAB 播放，可嵌入课件或分享。

## User Stories

1. 作为**教师**，我想要在 MATLAB 中运行一条命令就能播放完整动画，以便在课堂上流畅展示，无需手动操作多步。
2. 作为**教师**，我想要动画分阶段自动推进，每阶段间有停顿供讲解，以便控制课堂节奏。
3. 作为**教师**，我想要立柱和屋顶母线用不同颜色区分，以便学生一眼区分「支撑结构」和「屋顶骨架」。
4. 作为**教师**，我想要两组母线（u=const 与 v=const）颜色略有区分，以便演示双重直纹面的两组直线方向。
5. 作为**教师**，我想要立柱从地面动态「生长」起来、母线从一端动态「延展」出来，以便让学生看到「建造的过程」而非静态成品。
6. 作为**教师**，我想要一个固定的侧面俯视视角（az=−35°, el=30°），以便马鞍面两个方向的起伏都清晰可见。
7. 作为**教师**，我想要逐根逐条出现，每根之间有短暂停顿，以便有时间指给学生们看「这是直线」。
8. 作为**教师**，我想要动画最终导出为 mp4 视频文件，以便在没有 MATLAB 的电脑上播放或在课件中引用。
9. 作为**教师**，我想要同时导出 gif 动画，以便嵌入 PPT 自动循环播放。
10. 作为**教师**，我想要立柱顶点高度贴合双曲抛物面的曲面方程，以便数学上严谨——柱顶 z 值 = 曲面方程在该 (x,y) 处的 z 值。
11. 作为**教师**，我想要动画下方有一层半透明的曲面片，以便直观看到母线条与目标曲面的空间关系。
12. 作为**学生**，我想要看到每组母线条确实是直线（两点之间无弯曲），以便相信「双曲抛物面可由直线构成」。
13. 作为**学生**，我想要看到立柱沿椭圆环排列（而非矩形或圆形），以便理解这是真实鸟巢体育场的简化模型。
14. 作为**学生**，我想要动画节奏足够慢，以便跟上老师的讲解节奏并思考每条线的几何意义。
15. 作为**开发者**（后续迭代），我想要几何计算模块独立可测试，以便修改参数后能快速验证数学正确性。
16. 作为**开发者**，我想要代码模块化分离（几何/动画/驱动/测试），以便维护和复用。

## Implementation Decisions

### ID-1: 代码架构（模块化）
- **模块 1** `nest_geometry.m`：纯函数，无副作用，返回立柱坐标、母线端点、曲面网格、椭圆地面环。可独立单元测试。
- **模块 2** `nest_animation.m`：操作 figure/axes，分三阶段渲染，每阶段内逐根生长/延展动画。接收可选的 VideoWriter 句柄用于录制。
- **模块 3** `run_nest_demo.m`：驱动入口，组装参数→调用 geometry→调用 animation。提供 `record` 开关控制是否导出 mp4，`gif` 开关控制是否导出 gif。
- **模块 4** `test_nest_geometry.m`：单元测试套件。

### ID-2: 数学核心（双重直纹面）
- 曲面方程：`z = c·(x²/a² − y²/b²)`，默认 `a=6, b=5, c=2.5`。
- 参数化：`u, v ∈ [−1,1]`，`x = a(u+v)/2`, `y = b(v−u)/2`, `z = c·u·v`。
- 证明：固定 u 得 z = c·u₀·v（线性于 v）→ 直线；固定 v 同理 → 双重直纹面。
- 母线用两端点定义：plot3 两笔端点即一笔直线，无需中间采样。
- 立柱沿椭圆环 `x = a·cosθ, y = b·sinθ` 均匀分布 N=10 根，柱顶 z = `c·(x²/a² − y²/b²)` = `c·cos(2θ)`。

### ID-3: 动画实现（生长/延展）
- **生长动画**：立柱 handle 初始化为零长（ZData=[0,0]），每帧增长 t·z_target（t=0→1），共 `n_pillar=8` 帧。通过 `set(h,'ZData',[0,z_current])` 更新。
- **延展动画**：母线 handle 初始化为零长（起点=终点在参数负端），每帧从负端向正端延展 t·(P_pos−P_neg)，共 `n_rule=10` 帧。通过 `set(h,'XData',...,'YData',...,'ZData',...)` 三维同步更新。
- **重要**：所有 handle 必须在动画循环前创建并初始化为零长，避免「先全出现再生长」的视觉 bug（来自 prototype 验证结论）。

### ID-4: 出现顺序
- 立柱：逆时针（θ=0 起，即长轴正端），每根生长完成后 pause(dt=0.15s)。
- 母线：先 u=const 组（颜色 #EDB120），后 v=const 组（颜色 #FFD060）。每组内沿参数从小到大扫掠（u 从 −1→+1 方向，v 从 −1→+1 方向）。
- 曲面片：阶段 2 开始时先 `surf` 半透明片（FaceAlpha=0.2），再铺母线。

### ID-5: 录制策略（主动帧循环）
- 不依赖 `pause` 实际耗时控制录制节奏——每一渲染帧后显式 `writeVideo(vw, getframe(fig))`。
- 生长/延展的每帧都录制，每根完成后追加 `round(dt*fps)` 帧静帧。
- gif 导出：使用 `rgb2ind` 256 色调色板 `nodither`，通过 `imwrite(...,'WriteMode','append')` 逐帧追加。
- 两个录制可合并到同一个帧循环中（同时写 mp4 和采集 gif 帧），避免重复渲染。

### ID-6: 视觉规范
- 配色：立柱 #0072BD（`[0 114 189]/255`），u 组母线 #EDB120（`[237 177 32]/255`），v 组母线 #FFD060（`[255 208 96]/255`），曲面片 FaceColor #EDB120 alpha 0.2，地面环 #7F8C8D。
- 线宽：立柱 2，母线 1.5。
- 背景：白色 fig，投影仪友好。
- 相机：固定 view([-35,30])，axis equal。
- 标题：阶段切换时 `title('阶段1：立柱升起')` / `title('阶段2：直线构成曲面')`。
- 地面：仅椭圆环，不画方格网。

### ID-7: 几何参数（默认值，集中在脚本顶部常量）
`a=6, b=5, c=2.5, N=10, Mu=9, Mv=9, n_pillar=8, n_rule=10, dt=0.15, hold_t=0.8, fps=30, alpha_surf=0.2`

### ID-8: gif 导出
- 在帧循环中逐帧采集 `frame = getframe(fig)`，`[im,map] = rgb2ind(frame.cdata, 256, 'nodither')`。
- 第一帧 `imwrite(im,map,gif_path,'gif','LoopCount',Inf,'DelayTime',1/fps)`。
- 后续帧 `imwrite(im,map,gif_path,'gif','WriteMode','append','DelayTime',1/fps)`。

## Testing Decisions

### 测试策略
- **最高接缝优先**：优先测试 `nest_geometry`（纯函数，可自动化），动画模块以人工验收为主。
- **只测外部行为**：几何测试验证数学正确性（母线中点在曲面上、柱顶贴合），不测内部变量名或临时变量。
- **避免测试实现细节**：不测 `set` 调用次数、不测 `drawnow` 时机、不测内部 handle 命名。

### 接缝 1: `nest_geometry.m` 单元测试（`test_nest_geometry.m`）
- **TC1.1** 母线中点在曲面上：对每条母线两端点取中点 M，assert `|M.z − c·(M.x²/a² − M.y²/b²)| < 1e-10`。
- **TC1.2** 立柱在椭圆上：assert `|(x_i/a)²+(y_i/b)² − 1| < 1e-10`。
- **TC1.3** 柱顶贴合曲面：assert `|z_i − c·(x_i²/a² − y_i²/b²)| < 1e-10`。
- **TC1.4** u=const 母线全段在曲面上：除中点外，取 t=0.25、0.75 插值点也在曲面上。
- **TC1.5** v=const 母线同理。
- **TC1.6** 边界处理：N<3 抛错、a≤0 抛错、Mu/Mv<2 自动 clamp 到 2。
- **TC1.7** 曲面网格覆盖椭圆域：surf mesh 的 X/Y 范围覆盖 [−a,a]×[−b,b]。

### 接缝 2: 实时动画人工验收（`run_nest_demo(record=false)`）
- 在 MATLAB figure 中观看完整动画，确认三阶段清晰、生长/延展流畅、颜色正确、视角正确。

### 接缝 3: mp4/gif 产物检查（`run_nest_demo(record=true, gif=true)`）
- **TC3.1** 输出文件存在：`out/nest.mp4` 和 `out/nest.gif` 均非空。
- **TC3.2** mp4 可播放：用系统默认播放器打开，无编解码错误。
- **TC3.3** mp4 内容正确：半透明曲面可见、蓝色立柱与橙色母线颜色分明、生长/延展过程可见。
- **TC3.4** gif 可播放：橙色（#EDB120 和 #FFD060）明显可辨，动画循环正常。

### 接缝 4: Handle 生命周期（`nest_animation.m` 内部验证）
- **TC4.1** 动画完成后无句柄泄露：`gobjects` 数组长度与创建数量一致，无悬挂 handle。
- **TC4.2** 零长初态验证：每根立柱/母线的初始 `ZData`/`XData`/`YData` 为退化线段（起点=终点）。

### 接缝 5: 跨平台兼容
- **TC5.1** 在 Windows 10 22H2 + MATLAB R2021b 上完整运行，所有接缝通过。
- **TC5.2** 若条件允许，在 MATLAB R2020b+ 其他版本上验证 `VideoWriter('MPEG-4')` 和 `rgb2ind` 兼容性。

## Out of Scope

- 交互式 GUI / App Designer 界面
- 多语言字幕/配音/配乐
- 实时参数滑块调节界面
- 真实鸟巢的复杂次结构、编织纹理或材料渲染
- 多段动画的时间线编辑器
- 部署为 Web 应用或独立可执行文件
- 支持 macOS/Linux 平台的 MATLAB 兼容性测试（当前仅 Windows）

## Further Notes

1. 本 PRD 基于 `docs/superpowers/specs/2026-06-19-nest-hyperbolic-paraboloid-animation-design.md` 的 Grilled 版本编写，所有决策已经 brainstorming + grill-with-docs + prototype 三层验证。
2. 原型（已清理）已验证 `surf FaceAlpha + VideoWriter`、`set-ZData + writeVideo` 逐帧录制、`rgb2ind` gif 导出三者均可行。
3. 规范设计稿 `designs/nest-hp-animation/Nest Animation Design.html` 可作为视觉参考，浏览器打开 `http://localhost:4311/nest-hp-animation/Nest Animation Design.html` 查看 3D 预览。
4. 领域术语参见 `CONTEXT.md`（含中文/英文/禁止同义词表）。
5. 后续迭代可能扩展：母线裁剪到椭圆边界、相机旋转展示、构件标签/注释。
