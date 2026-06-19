# 🏟️ 鸟巢双曲抛物面动画 — Nest HP Animation

课堂演示：用直线搭建双曲抛物面（马鞍面）。基于鸟巢（国家体育场）真实构造原理，MATLAB + Python 双语言多阶段 3D 动画。

## 数学原理

双曲抛物面为双重直纹面（doubly ruled surface）——过曲面上每一点恰有两条直线。

```math
z = c · (x²/ahp² − y²/bhp²) + z_offset
```

通过 **u 族**（`x/ahp − y/bhp = const`）和 **v 族**（`x/ahp + y/bhp = const`）直母线与内外椭圆求交，生成规则交叉编织网，模拟鸟巢屋顶钢结构。

## 动画分镜

```
阶段 0: 空坐标系           过渡 0→1: 立柱逐根生长       阶段 1: 立柱完成
(坐标轴+地面网格)          (从 z=0 线性升到HP曲面)    (浅灰立柱，高度各异)

过渡 1→2: 屋顶线逐条铺出   阶段 2: 编织网完成
(先u族后v族，逐条延展)      (橙色直母线交叉编织)
```

## 环境要求

- **MATLAB**: R2021b+
- **Python**: 3.8+ + `pip install -r src/python/requirements.txt`

## 快速开始

### MATLAB

```matlab
cd src/matlab
addpath('.')
run_nest_demo           % 实时动画
run_nest_demo(true)     % 录制 mp4 → out/nest.mp4
```

### Python

```bash
cd src/python
pip install -r requirements.txt
python run_nest_demo.py                  # 实时动画（需要 GUI）
python run_nest_demo.py out/nest.mp4     # 导出 mp4（需 ffmpeg）
```

### 运行测试

```matlab
run('src/matlab/test/test_nest_geometry.m')   % MATLAB: 7 项测试
```

```bash
cd src/python && pytest test_nest_geometry.py -v   % Python: 9 项测试
```

## 参数说明

| 参数 | 值 | 说明 |
|------|-----|------|
| ahp, bhp | 80, 72 | HP 曲面曲率参数 |
| c, z_offset | 18, 23.2 | 翘起量和垂直偏移 |
| a_out, b_out | 60, 53.5 | 外椭圆（外壳投影） |
| a_in, b_in | 34.4, 22.4 | 内椭圆（开口投影） |
| u族, v族 | 各 50 条 | u,v ∈ [-1.06, 1.06] |
| 相机 | az=-20°, el=25° | 侧俯视 |
| 立柱 | 浅灰 [0.75 0.75 0.75], 3pt | 仿钢结构 |
| 屋顶线 | 橙色 #EDB120, 2pt | 直纹母线编织 |

## 文件结构

```
src/
├── matlab/
│   ├── nest_geometry.m           几何引擎（HP曲面 + 椭圆求交 + 直母线）
│   ├── nest_animation.m          三阶段动画（生长+延展过渡）
│   ├── run_nest_demo.m           驱动入口 + mp4 导出
│   └── test/
│       └── test_nest_geometry.m  单元测试（7项）
├── python/
│   ├── nest_geometry.py          几何引擎（对应MATLAB）
│   ├── nest_animation.py         三阶段动画（matplotlib FuncAnimation）
│   ├── run_nest_demo.py          驱动入口
│   ├── test_nest_geometry.py     pytest 单元测试（9项）
│   └── requirements.txt          依赖清单
docs/
├── superpowers/
│   ├── specs/2026-06-19-nest-iteration2-design.md    设计规格
│   ├── prd/nest-iteration2-prd.md                    产品需求
│   └── plans/2026-06-19-nest-iteration2-plan.md      实现计划
```

## 设计文档

- [迭代2 设计规格](docs/superpowers/specs/2026-06-19-nest-iteration2-design.md)
- [迭代2 PRD](docs/superpowers/prd/nest-iteration2-prd.md)
- [迭代2 实现计划](docs/superpowers/plans/2026-06-19-nest-iteration2-plan.md)
- [GitHub Issues](https://github.com/shanhuyuli/nest/issues)
- [领域术语表](CONTEXT.md)
- [迭代1 设计稿](designs/nest-hp-animation/Nest Animation Design.html)

## 许可证

MIT
