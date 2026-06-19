# Nest Iteration 2 Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor MATLAB animation to match real Bird's Nest hyperbolic-paraboloid ruled-surface construction, and independently implement the same in Python.

**Architecture:** Process-script architecture — pure geometry engine (no side effects) → animation renderer (figure manipulation) → driver entry (orchestration + export). MATLAB and Python share identical math but use language-idiomatic rendering.

**Tech Stack:** MATLAB R2021b (plot3/drawnow/VideoWriter), Python 3 (numpy + matplotlib + mpl_toolkits.mplot3d + FuncAnimation + pytest)

**Ref Spec:** `docs/superpowers/specs/2026-06-19-nest-iteration2-design.md`  
**Ref PRD:** `docs/superpowers/prd/nest-iteration2-prd.md`  
**Ref Prototype:** `src/matlab/prototype_geo_verify.m` (throwaway, delete in Issue #12)

---

## Dependency Graph

```
                    ┌──────────────┐  ┌──────────────┐
                    │ Issue #6     │  │ Issue #9     │
                    │ MATLAB       │  │ Python       │
                    │ Geometry     │  │ Geometry     │
                    └──────┬───────┘  └──────┬───────┘
                           │                 │
              ┌────────────▼───┐  ┌──────────▼─────┐
              │ Issue #7       │  │ Issue #10      │
              │ MATLAB         │  │ Python         │
              │ Unit Tests     │  │ Unit Tests     │
              └──────┬─────────┘  └──────┬─────────┘
                     │                   │
         ┌───────────▼───────┐  ┌────────▼──────────┐
         │ Issue #8          │  │ Issue #11         │
         │ MATLAB            │  │ Python            │
         │ Animation+Driver  │  │ Animation+Driver  │
         └──────────┬────────┘  └────────┬──────────┘
                    │                    │
                    └──────────┬─────────┘
                               │
                    ┌──────────▼─────────┐
                    │ Issue #12          │
                    │ Cleanup + README   │
                    └────────────────────┘
```

**Parallel groups:**
- **Group 1**: Issues #6 + #9 (zero blockers, start immediately)
- **Group 2**: Issues #7 + #10 (blocked by respective Group 1)
- **Group 3**: Issues #8 + #11 (blocked by respective Group 2)
- **Group 4**: Issue #12 (blocked by Group 3)

---

## File Map

```
src/matlab/
├── nest_geometry.m        [OVERWRITE] Pure geometry engine
├── nest_animation.m       [OVERWRITE] 3-stage animation renderer
├── run_nest_demo.m        [OVERWRITE] Driver + export
└── test_nest_geometry.m   [CREATE]    Unit tests

src/python/
├── nest_geometry.py       [CREATE] Pure geometry engine
├── nest_animation.py      [CREATE] Animation renderer
├── run_nest_demo.py       [CREATE] Driver + export
├── test_nest_geometry.py  [CREATE] Unit tests
└── requirements.txt       [CREATE] numpy, matplotlib, pytest

tmp/                       [DELETE]  Remove all proto output
```

---

## Core Parameters (all tasks reference these)

```matlab
% HP Surface: z = c*(x^2/ahp^2 - y^2/bhp^2) + z_offset
ahp     = 80;       % HP a parameter
bhp     = 72;       % HP b parameter
c       = 18;       % Saddle scale (large height diff for classroom)
z_offset = 23.2;    % Vertical offset (z_min ~13.3)

% Ellipse boundaries
a_out = 60;   b_out = 53.5;
a_in  = 34.4; b_in  = 22.4;

% Rulings
Nu = 50;  Nv = 50;
u_range = [-1.06, 1.06];
v_range = [-1.06, 1.06];

% Visual
pillar_color = [0.75 0.75 0.75];  % Light gray
roof_color   = [0.93 0.69 0.13];  % Orange #EDB120
pillar_width = 3;
roof_width   = 2;

% Camera
az = -20;  el = 25;
```

---

## Group 1 — Geometry Engines (independent, parallel)

### Task 1: Issue #6 — MATLAB: Refactor nest_geometry.m

**Files:**
- Overwrite: `src/matlab/nest_geometry.m`

**Function signature:**
```matlab
function G = nest_geometry(p)
% p: struct with fields a_out, b_out, a_in, b_in, ahp, bhp, c, z_offset, Nu, Nv, u_range, v_range
% G: struct with fields pillars (Nx4), roof_segments (cell), ellipse_outer, ellipse_inner
```

- [ ] **Step 1: Define HP surface helper**

```matlab
function G = nest_geometry(p)
    % Pure geometry: compute all pillar positions and roof segments
    hpZ = @(x,y) p.c * (x.^2 ./ p.ahp^2 - y.^2 ./ p.bhp^2) + p.z_offset;
```

- [ ] **Step 2: Implement line-ellipse intersection**

```matlab
    function pts = lineEllipseIntersect(m, d, a_ell, b_ell)
        A = 1/a_ell^2 + m^2/b_ell^2;
        B = 2*m*d / b_ell^2;
        C = d^2/b_ell^2 - 1;
        disc = B^2 - 4*A*C;
        if disc < 0
            pts = zeros(0,2);
        elseif disc < 1e-12
            x = -B/(2*A);
            pts = [x, m*x + d];
        else
            sd = sqrt(disc);
            x1 = (-B + sd)/(2*A);
            x2 = (-B - sd)/(2*A);
            pts = [x1, m*x1+d; x2, m*x2+d];
        end
    end
```

- [ ] **Step 3: Implement point-in-ellipse test**

```matlab
    function inside = pointInEllipse(x, y, a_ell, b_ell)
        inside = (x^2/a_ell^2 + y^2/b_ell^2) < 1;
    end
```

- [ ] **Step 4: Process one ruling family**

```matlab
    function [pillars, segments] = processFamily(vals, slope, is_u_family)
        pillars_local = [];
        segments_local = {};
        for vi = 1:length(vals)
            val = vals(vi);
            if is_u_family
                d = -slope * p.ahp * val;
            else
                d = -slope * p.ahp * val;
            end
            m = slope;
            pts_out = lineEllipseIntersect(m, d, p.a_out, p.b_out);
            pts_in  = lineEllipseIntersect(m, d, p.a_in, p.b_in);
            all_pts = [];
            for j = 1:size(pts_out,1)
                all_pts = [all_pts; pts_out(j,1), pts_out(j,2), 1, pts_out(j,1)];
            end
            for j = 1:size(pts_in,1)
                all_pts = [all_pts; pts_in(j,1), pts_in(j,2), 2, pts_in(j,1)];
            end
            if size(all_pts,1) >= 2
                [~, idx] = sort(all_pts(:,4));
                all_pts = all_pts(idx, :);
                for j = 1:size(all_pts,1)-1
                    p1 = all_pts(j, 1:2);  p2 = all_pts(j+1, 1:2);
                    t1 = all_pts(j, 3);    t2 = all_pts(j+1, 3);
                    if t1 == 2 && t2 == 2, continue; end
                    mid_x = (p1(1)+p2(1))/2;  mid_y = (p1(2)+p2(2))/2;
                    if pointInEllipse(mid_x, mid_y, p.a_in, p.b_in), continue; end
                    z1 = hpZ(p1(1), p1(2));  z2 = hpZ(p2(1), p2(2));
                    pillars_local = [pillars_local; p1, 0, z1; p2, 0, z2];
                    segments_local{end+1} = [p1(1), p1(2), z1; p2(1), p2(2), z2];
                end
            end
        end
        pillars = pillars_local;
        segments = segments_local;
    end
```

- [ ] **Step 5: Generate u-family (50 lines, slope = +bhp/ahp)**

```matlab
    u_vals = linspace(p.u_range(1), p.u_range(2), p.Nu);
    slope_u = p.bhp / p.ahp;
    [G.pillars_u, G.segments_u] = processFamily(u_vals, slope_u, true);
```

- [ ] **Step 6: Generate v-family (50 lines, slope = -bhp/ahp)**

```matlab
    v_vals = linspace(p.v_range(1), p.v_range(2), p.Nv);
    slope_v = -p.bhp / p.ahp;
    [G.pillars_v, G.segments_v] = processFamily(v_vals, slope_v, false);
```

- [ ] **Step 7: Merge results and compute ellipse outlines**

```matlab
    G.pillars = [G.pillars_u; G.pillars_v];
    G.roof_segments = [G.segments_u, G.segments_v];
    theta = linspace(0, 2*pi, 300);
    G.ellipse_outer = [p.a_out*cos(theta); p.b_out*sin(theta)];
    G.ellipse_inner = [p.a_in*cos(theta); p.b_in*sin(theta)];
end
```

- [ ] **Step 8: Commit**

```bash
git add src/matlab/nest_geometry.m
git commit -m "feat: refactor nest_geometry with ruled-surface intersection logic"
```

---

### Task 2: Issue #9 — Python: Create nest_geometry.py

**Files:**
- Create: `src/python/nest_geometry.py`

**Same math, Python-idiomatic. Module exports one function:**

```python
def compute_geometry(a_out=60, b_out=53.5, a_in=34.4, b_in=22.4,
                     ahp=80, bhp=72, c=18, z_offset=23.2,
                     Nu=50, Nv=50, u_range=(-1.06, 1.06), v_range=(-1.06, 1.06)):
    """Return dict with keys: pillars (Nx4 ndarray), roof_segments (list of 2x3 ndarray),
       ellipse_outer (2xN ndarray), ellipse_inner (2xN ndarray)"""
```

- [ ] **Step 1: Create file with hpZ function**

```python
import numpy as np

def _hpZ(x, y, c, ahp, bhp, z_offset):
    return c * (x**2 / ahp**2 - y**2 / bhp**2) + z_offset
```

- [ ] **Step 2: Implement line-ellipse intersection**

```python
def _line_ellipse_intersect(m, d, a_ell, b_ell):
    A = 1/a_ell**2 + m**2/b_ell**2
    B = 2*m*d / b_ell**2
    C = d**2/b_ell**2 - 1
    disc = B**2 - 4*A*C
    if disc < 0:
        return np.empty((0, 2))
    elif disc < 1e-12:
        x = -B/(2*A)
        return np.array([[x, m*x + d]])
    else:
        sd = np.sqrt(disc)
        x1 = (-B + sd)/(2*A)
        x2 = (-B - sd)/(2*A)
        return np.array([[x1, m*x1+d], [x2, m*x2+d]])
```

- [ ] **Step 3: Implement point-in-ellipse check**

```python
def _point_in_ellipse(x, y, a_ell, b_ell):
    return (x**2/a_ell**2 + y**2/b_ell**2) < 1
```

- [ ] **Step 4: Implement family processor**

```python
def _process_family(vals, slope, a_hp, a_out, b_out, a_in, b_in, c, ahp, bhp, z_offset):
    pillars = []
    segments = []
    hpZ = lambda x, y: _hpZ(x, y, c, ahp, bhp, z_offset)
    for val in vals:
        d = -slope * a_hp * val
        m = slope
        pts_out = _line_ellipse_intersect(m, d, a_out, b_out)
        pts_in  = _line_ellipse_intersect(m, d, a_in, b_in)
        all_pts = []
        for xp, yp in pts_out:
            all_pts.append((xp, yp, 1, xp))
        for xp, yp in pts_in:
            all_pts.append((xp, yp, 2, xp))
        if len(all_pts) >= 2:
            all_pts.sort(key=lambda p: p[3])
            for j in range(len(all_pts)-1):
                p1x, p1y, t1, _ = all_pts[j]
                p2x, p2y, t2, _ = all_pts[j+1]
                if t1 == 2 and t2 == 2:
                    continue
                mx, my = (p1x+p2x)/2, (p1y+p2y)/2
                if _point_in_ellipse(mx, my, a_in, b_in):
                    continue
                z1, z2 = hpZ(p1x, p1y), hpZ(p2x, p2y)
                pillars.append([p1x, p1y, 0, z1])
                pillars.append([p2x, p2y, 0, z2])
                segments.append(np.array([[p1x, p1y, z1], [p2x, p2y, z2]]))
    return np.array(pillars), segments
```

- [ ] **Step 5: Main compute function**

```python
def compute_geometry(a_out=60, b_out=53.5, a_in=34.4, b_in=22.4,
                     ahp=80, bhp=72, c=18, z_offset=23.2,
                     Nu=50, Nv=50, u_range=(-1.06, 1.06), v_range=(-1.06, 1.06)):
    u_vals = np.linspace(u_range[0], u_range[1], Nu)
    v_vals = np.linspace(v_range[0], v_range[1], Nv)
    slope_u = bhp / ahp
    slope_v = -bhp / ahp
    pillars_u, segs_u = _process_family(u_vals, slope_u, ahp, a_out, b_out, a_in, b_in, c, ahp, bhp, z_offset)
    pillars_v, segs_v = _process_family(v_vals, slope_v, ahp, a_out, b_out, a_in, b_in, c, ahp, bhp, z_offset)
    pillars = np.vstack([pillars_u, pillars_v]) if len(pillars_u) > 0 and len(pillars_v) > 0 else pillars_u if len(pillars_u) > 0 else pillars_v
    theta = np.linspace(0, 2*np.pi, 300)
    ellipse_outer = np.array([a_out*np.cos(theta), b_out*np.sin(theta)])
    ellipse_inner = np.array([a_in*np.cos(theta), b_in*np.sin(theta)])
    return {
        'pillars': pillars,
        'roof_segments': segs_u + segs_v,
        'ellipse_outer': ellipse_outer,
        'ellipse_inner': ellipse_inner,
    }
```

- [ ] **Step 6: Create requirements.txt**

```txt
numpy>=1.21
matplotlib>=3.5
pytest>=7.0
```

- [ ] **Step 7: Commit**

```bash
git add src/python/nest_geometry.py src/python/requirements.txt
git commit -m "feat: add Python nest_geometry module with ruled-surface math"
```

---

## Group 2 — Unit Tests (parallel, blocked by respective Group 1)

### Task 3: Issue #7 — MATLAB: Create test_nest_geometry.m

**Files:**
- Create: `src/matlab/test_nest_geometry.m`

- [ ] **Step 1: Test HP surface function**

```matlab
function test_nest_geometry()
    p = struct('a_out',60,'b_out',53.5,'a_in',34.4,'b_in',22.4,...
               'ahp',80,'bhp',72,'c',18,'z_offset',23.2,...
               'Nu',50,'Nv',50,'u_range',[-1.06,1.06],'v_range',[-1.06,1.06]);
    G = nest_geometry(p);
    
    % Test 1: HP surface at known points
    hpZ = @(x,y) p.c*(x.^2/p.ahp^2 - y.^2/p.bhp^2) + p.z_offset;
    assert(abs(hpZ(60,0) - (18*(3600/6400) + 23.2)) < 1e-10, 'hpZ at (60,0) failed');
    assert(abs(hpZ(0,53.5) - (18*(-2862.25/5184) + 23.2)) < 1e-10, 'hpZ at (0,53.5) failed');
    disp('Test 1 PASSED: hpZ values correct');
```

- [ ] **Step 2: Test pillar tops on HP surface**

```matlab
    % Test 2: All pillar tops lie on HP surface
    max_err = 0;
    for i = 1:size(G.pillars, 1)
        z_calc = hpZ(G.pillars(i,1), G.pillars(i,2));
        max_err = max(max_err, abs(z_calc - G.pillars(i,4)));
    end
    assert(max_err < 1e-10, sprintf('Pillar top error too large: %.2e', max_err));
    disp('Test 2 PASSED: All pillar tops on HP surface');
```

- [ ] **Step 3: Test ruling midpoints on HP surface**

```matlab
    % Test 3: Ruling midpoints lie on HP surface
    mid_errors = [];
    for i = 1:length(G.roof_segments)
        seg = G.roof_segments{i};
        mid_x = (seg(1,1)+seg(2,1))/2;
        mid_y = (seg(1,2)+seg(2,2))/2;
        mid_z = (seg(1,3)+seg(2,3))/2;
        mid_errors(end+1) = abs(mid_z - hpZ(mid_x, mid_y));
    end
    assert(max(mid_errors) < 1e-10, sprintf('Ruling midpoint error too large: %.2e', max(mid_errors)));
    assert(mean(mid_errors) < 1e-10, 'Average ruling midpoint error too large');
    disp('Test 3 PASSED: All ruling midpoints on HP surface');
```

- [ ] **Step 4: Test minimum pillar height**

```matlab
    % Test 4: All pillars above ground
    assert(all(G.pillars(:,4) >= 13), 'Some pillars below minimum height');
    disp('Test 4 PASSED: All pillars above minimum height');
```

- [ ] **Step 5: Test segment count**

```matlab
    % Test 5: Reasonable output counts
    assert(size(G.pillars, 1) > 100, 'Too few pillars');
    assert(length(G.roof_segments) > 50, 'Too few roof segments');
    disp('Test 5 PASSED: Output counts reasonable');
    disp('ALL TESTS PASSED');
end
```

- [ ] **Step 6: Run tests**

```bash
cd /d/Workspace/nest && matlab -batch "run('src/matlab/test_nest_geometry.m')"
```
Expected: ALL TESTS PASSED

- [ ] **Step 7: Commit**

```bash
git add src/matlab/test_nest_geometry.m
git commit -m "test: add unit tests for nest_geometry"
```

---

### Task 4: Issue #10 — Python: Create test_nest_geometry.py

**Files:**
- Create: `src/python/test_nest_geometry.py`

- [ ] **Step 1: Import and setup**

```python
import numpy as np
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from nest_geometry import compute_geometry

def test_hpZ_values():
    from nest_geometry import _hpZ
    z1 = _hpZ(60, 0, 18, 80, 72, 23.2)
    assert abs(z1 - (18*(3600/6400) + 23.2)) < 1e-10
    z2 = _hpZ(0, 53.5, 18, 80, 72, 23.2)
    assert abs(z2 - (18*(-2862.25/5184) + 23.2)) < 1e-10
```

- [ ] **Step 2: Test geometry output**

```python
def test_pillar_tops_on_surface():
    G = compute_geometry()
    pillars = G['pillars']
    from nest_geometry import _hpZ
    for x, y, _, z in pillars:
        z_calc = _hpZ(x, y, 18, 80, 72, 23.2)
        assert abs(z_calc - z) < 1e-10

def test_ruling_midpoints_on_surface():
    G = compute_geometry()
    from nest_geometry import _hpZ
    errors = []
    for seg in G['roof_segments']:
        mid = seg.mean(axis=0)
        z_calc = _hpZ(mid[0], mid[1], 18, 80, 72, 23.2)
        errors.append(abs(z_calc - mid[2]))
    assert max(errors) < 1e-10

def test_min_pillar_height():
    G = compute_geometry()
    assert np.all(G['pillars'][:, 3] >= 13)

def test_output_counts():
    G = compute_geometry()
    assert len(G['pillars']) > 100
    assert len(G['roof_segments']) > 50
```

- [ ] **Step 3: Run tests**

```bash
cd src/python && python -m pytest test_nest_geometry.py -v
```
Expected: 5 passed

- [ ] **Step 4: Commit**

```bash
git add src/python/test_nest_geometry.py
git commit -m "test: add pytest unit tests for nest_geometry"
```

---

## Group 3 — Animation + Driver (parallel, blocked by respective Group 2)

### Task 5: Issue #8 — MATLAB: Refactor nest_animation.m + run_nest_demo.m

**Files:**
- Overwrite: `src/matlab/nest_animation.m`
- Overwrite: `src/matlab/run_nest_demo.m`

- [ ] **Step 1: nest_animation.m — Stage 0 (axes + grid)**

```matlab
function nest_animation(G, p, ax, recorder)
    % Stage 0: Empty coordinate system
    cla(ax); hold(ax, 'on');
    view(ax, [p.az, p.el]);
    daspect(ax, [1 1 1]);
    xlim(ax, [-p.a_out-5, p.a_out+5]);
    ylim(ax, [-p.b_out-5, p.b_out+5]);
    zlim(ax, [0, max(G.pillars(:,4))*1.1]);
    xlabel(ax, 'X'); ylabel(ax, 'Y'); zlabel(ax, 'Z');
    grid(ax, 'on');
    
    % Outer ellipse dashed outline on ground
    plot3(ax, G.ellipse_outer(1,:), G.ellipse_outer(2,:), zeros(1,300), ...
          'k--', 'LineWidth', 1);
    % Inner ellipse dotted outline
    plot3(ax, G.ellipse_inner(1,:), G.ellipse_inner(2,:), zeros(1,300), ...
          'k:', 'LineWidth', 1);
    title(ax, 'Stage 0: Coordinate System');
    drawnow;
    pause_or_hold(p.hold_t, recorder, p.fps);
```

- [ ] **Step 2: Helper — pause or record**

```matlab
    function pause_or_hold(duration, recorder, fps)
        if ~isempty(recorder)
            for f = 1:round(duration * fps)
                writeVideo(recorder, getframe(ax.Parent));
            end
        else
            pause(duration);
        end
    end
```

- [ ] **Step 3: Transition 0→1 — Pillars rise**

```matlab
    % Transition 0->1: Pillars grow from z=0 to target height
    title(ax, 'Stage 1: Pillars Rising');
    n_pillars = size(G.pillars, 1);
    n_frames = 30;  % Number of animation frames
    pillar_handles = gobjects(n_pillars, 1);
    
    % Create all pillar handles at zero height
    for i = 1:n_pillars
        pillar_handles(i) = plot3(ax, ...
            [G.pillars(i,1), G.pillars(i,1)], ...
            [G.pillars(i,2), G.pillars(i,2)], ...
            [0, 0], ...
            'Color', p.pillar_color, 'LineWidth', p.pillar_width);
    end
    
    for frm = 1:n_frames
        t = frm / n_frames;  % 0 -> 1
        for i = 1:n_pillars
            set(pillar_handles(i), 'ZData', [0, t * G.pillars(i,4)]);
        end
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        else
            pause(0.05);
        end
    end
    pause_or_hold(p.hold_t, recorder, p.fps);
```

- [ ] **Step 4: Transition 1→2 — Roof lines appear (u-family then v-family)**

```matlab
    % Transition 1->2: Roof segments appear
    title(ax, 'Stage 2: Roof Weave');
    n_segs = length(G.roof_segments);
    seg_handles = gobjects(n_segs, 1);
    
    % Create zero-length handles
    for i = 1:n_segs
        seg = G.roof_segments{i};
        seg_handles(i) = plot3(ax, [seg(1,1), seg(1,1)], ...
                                   [seg(1,2), seg(1,2)], ...
                                   [seg(1,3), seg(1,3)], ...
                                   'Color', p.roof_color, 'LineWidth', p.roof_width);
    end
    
    n_frames_seg = 20;
    for frm = 1:n_frames_seg
        t = frm / n_frames_seg;
        for i = 1:n_segs
            seg = G.roof_segments{i};
            x_e = seg(1,1) + t*(seg(2,1)-seg(1,1));
            y_e = seg(1,2) + t*(seg(2,2)-seg(1,2));
            z_e = seg(1,3) + t*(seg(2,3)-seg(1,3));
            set(seg_handles(i), 'XData', [seg(1,1), x_e], ...
                                'YData', [seg(1,2), y_e], ...
                                'ZData', [seg(1,3), z_e]);
        end
        drawnow;
        if ~isempty(recorder)
            writeVideo(recorder, getframe(ax.Parent));
        else
            pause(0.05);
        end
    end
    pause_or_hold(1.5, recorder, p.fps);
end
```

- [ ] **Step 5: run_nest_demo.m — Driver**

```matlab
function run_nest_demo(varargin)
    % Parse optional 'record' flag
    opts.record = false;
    opts.out = 'out/nest.mp4';
    if nargin >= 1 && islogical(varargin{1})
        opts.record = varargin{1};
    end
    
    % Parameters (matching prototype-verified values)
    p = struct(...
        'a_out',60,'b_out',53.5,'a_in',34.4,'b_in',22.4,...
        'ahp',80,'bhp',72,'c',18,'z_offset',23.2,...
        'Nu',50,'Nv',50,...
        'u_range',[-1.06,1.06],'v_range',[-1.06,1.06],...
        'az',-20,'el',25,...
        'pillar_color',[0.75 0.75 0.75],'pillar_width',3,...
        'roof_color',[0.93 0.69 0.13],'roof_width',2,...
        'fps',15,'hold_t',0.8);
    
    G = nest_geometry(p);
    fig = figure('Color','w','Position',[100,100,800,600]);
    ax = axes(fig);
    
    if opts.record
        mkdir('out');
        vw = VideoWriter(opts.out, 'MPEG-4');
        vw.FrameRate = p.fps;
        open(vw);
        nest_animation(G, p, ax, vw);
        close(vw);
        fprintf('Exported: %s\n', opts.out);
    else
        nest_animation(G, p, ax, []);
    end
end
```

- [ ] **Step 6: Run and verify**

```bash
# Live demo
matlab -batch "cd('D:/Workspace/nest'); run_nest_demo(false); pause(2); exit;"
# With recording
matlab -batch "cd('D:/Workspace/nest'); run_nest_demo(true);"
```

- [ ] **Step 7: Commit**

```bash
git add src/matlab/nest_animation.m src/matlab/run_nest_demo.m
git commit -m "feat: refactor nest_animation with 3-stage ruled-surface animation"
```

---

### Task 6: Issue #11 — Python: Create nest_animation.py + run_nest_demo.py

**Files:**
- Create: `src/python/nest_animation.py`
- Create: `src/python/run_nest_demo.py`

- [ ] **Step 1: nest_animation.py — import and setup**

```python
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from nest_geometry import compute_geometry

def animate_nest(save_path=None):
    G = compute_geometry()
    pillars = G['pillars']
    segments = G['roof_segments']
    ellipse_outer = G['ellipse_outer']
    ellipse_inner = G['ellipse_inner']
    
    fig = plt.figure(figsize=(8, 6), facecolor='white')
    ax = fig.add_subplot(111, projection='3d')
    ax.view_init(elev=25, azim=-20)
    ax.set_xlabel('X'); ax.set_ylabel('Y'); ax.set_zlabel('Z')
    ax.set_zlim(0, pillars[:, 3].max() * 1.1)
    
    # Ground ellipses
    ax.plot(ellipse_outer[0], ellipse_outer[1], 0, 'k--', lw=1)
    ax.plot(ellipse_inner[0], ellipse_inner[1], 0, 'k:', lw=1)
```

- [ ] **Step 2: Create pillar and segment line objects**

```python
    pillar_lines = []
    for x, y, _, z in pillars:
        line, = ax.plot([x, x], [y, y], [0, 0], color='#bfbfbf', lw=3)
        pillar_lines.append((line, z))
    
    seg_lines = []
    for seg in segments:
        line, = ax.plot([seg[0,0], seg[0,0]], [seg[0,1], seg[0,1]], 
                        [seg[0,2], seg[0,2]], color='#EDB120', lw=2)
        seg_lines.append((line, seg))
    
    ax.set_title('Stage 0: Coordinate System')
```

- [ ] **Step 3: Animation update function**

```python
    total_frames = 60
    n_pillars = len(pillar_lines)
    n_segs = len(seg_lines)
    pillar_growth_frames = 30
    seg_growth_frames = 30
    
    def update(frame):
        if frame < pillar_growth_frames:
            t = (frame + 1) / pillar_growth_frames
            ax.set_title('Stage 1: Pillars Rising')
            for i, (line, z_target) in enumerate(pillar_lines):
                z = t * z_target
                line.set_data_3d([line.get_xdata()[0], line.get_xdata()[0]],
                                 [line.get_ydata()[0], line.get_ydata()[0]],
                                 [0, z])
        elif frame < pillar_growth_frames + seg_growth_frames:
            ax.set_title('Stage 2: Roof Weave')
            t = (frame - pillar_growth_frames + 1) / seg_growth_frames
            for line, seg in seg_lines:
                interp = seg[0] + t * (seg[1] - seg[0])
                line.set_data_3d([seg[0,0], interp[0]], 
                                 [seg[0,1], interp[1]],
                                 [seg[0,2], interp[2]])
        return []
    
    anim = FuncAnimation(fig, update, frames=total_frames, interval=50, blit=False)
```

- [ ] **Step 4: Save or show**

```python
    if save_path:
        anim.save(save_path, writer='ffmpeg', fps=15)
        print(f'Exported: {save_path}')
    else:
        plt.show()
```

- [ ] **Step 5: run_nest_demo.py — Driver**

```python
#!/usr/bin/env python3
"""Run the Nest hyperbolic paraboloid animation."""
import sys
from nest_animation import animate_nest

if __name__ == '__main__':
    record = '--record' in sys.argv
    save_path = 'out/nest.mp4' if record else None
    if record:
        import os; os.makedirs('out', exist_ok=True)
    animate_nest(save_path=save_path)
```

- [ ] **Step 6: Run and verify**

```bash
cd src/python
python run_nest_demo.py                # Live animation
python run_nest_demo.py --record       # Export MP4
```

- [ ] **Step 7: Commit**

```bash
git add src/python/nest_animation.py src/python/run_nest_demo.py
git commit -m "feat: add Python nest animation with matplotlib FuncAnimation"
```

---

## Group 4 — Cleanup (after Group 3)

### Task 7: Issue #12 — Cleanup + Update README

**Files:**
- Delete: `src/matlab/prototype_geo_verify.m`
- Delete: `src/matlab/tmp/` (all proto output)
- Update: `README.md`

- [ ] **Step 1: Delete prototype**

```bash
rm -rf /d/Workspace/nest/src/matlab/prototype_geo_verify.m
rm -rf /d/Workspace/nest/src/matlab/tmp/
```

- [ ] **Step 2: Update README.md**

Replace/add sections for MATLAB and Python usage:

```markdown
## Quick Start

### MATLAB

\`\`\`matlab
% Live animation
run_nest_demo

% Export MP4
run_nest_demo(true)
\`\`\`

### Python

\`\`\`bash
cd src/python
pip install -r requirements.txt
python run_nest_demo.py              # Live animation
python run_nest_demo.py --record     # Export MP4
\`\`\`

## Project Structure

\`\`\`
src/matlab/
  nest_geometry.m        # Pure geometry engine (HP surface + ruling intersections)
  nest_animation.m       # 3-stage animation renderer
  run_nest_demo.m        # Driver + mp4 export
  test_nest_geometry.m   # Unit tests

src/python/
  nest_geometry.py       # Pure geometry engine (same math as MATLAB)
  nest_animation.py      # Animation renderer (matplotlib)
  run_nest_demo.py       # Driver + mp4 export
  test_nest_geometry.py  # pytest unit tests
  requirements.txt       # numpy, matplotlib, pytest
\`\`\`

## Key Parameters

| Param | Value | Description |
|-------|-------|-------------|
| HP Surface | z = 18*(x^2/80^2 - y^2/72^2) + 23.2 | Hyperbolic paraboloid |
| Outer ellipse | (60, 53.5) | Stadium footprint |
| Inner ellipse | (34.4, 22.4) | Roof opening |
| Rulings | 50u + 50v | Two families of straight generators |
| Pillars | Gray [0.75 0.75 0.75], lw=3 | Structural supports |
| Roof lines | Orange #EDB120, lw=2 | Ruled-surface weave |
| View | az=-20, el=25 | Side俯视 |
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git rm src/matlab/prototype_geo_verify.m
git rm -r src/matlab/tmp/
git commit -m "chore: cleanup prototype and update README with iteration 2 docs"
```

---

## Verification Checklist

After ALL issues complete, run:

- [ ] MATLAB geometry: `test_nest_geometry.m` — 5/5 passed
- [ ] Python geometry: `pytest test_nest_geometry.py` — 5/5 passed
- [ ] MATLAB live: `run_nest_demo` — 3-stage animation plays
- [ ] MATLAB export: `run_nest_demo(true)` — out/nest.mp4 exists
- [ ] Python live: `python run_nest_demo.py` — animation window opens
- [ ] Python export: `python run_nest_demo.py --record` — out/nest.mp4 exists
- [ ] No `prototype_geo_verify.m` in repo
- [ ] No `tmp/` directory in `src/matlab/`
