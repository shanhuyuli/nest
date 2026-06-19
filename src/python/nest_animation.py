"""Bird's Nest 3-stage animation using matplotlib."""
import os
import sys

# Headless environment detection (architecture review fix)
if 'DISPLAY' not in os.environ and 'WAYLAND_DISPLAY' not in os.environ:
    import matplotlib
    matplotlib.use('Agg')

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, FFMpegWriter
from nest_geometry import compute_geometry

AZ, EL = -20, 25
FPS = 18
DT_GROW = 0.03   # seconds per pillar
DT_RULE = 0.05   # seconds per roof segment
HOLD_T = 0.8     # pause between stages
FINAL_T = 2.0    # final hold


def run_animation(save_path=None):
    """Run 3-stage nest animation. If save_path is provided, export mp4."""
    G = compute_geometry()
    pillars = G['pillars']
    roof_segments = G['roof_segments']
    total_pillars = len(pillars)
    total_segments = len(roof_segments)

    fig = plt.figure(figsize=(10, 8), facecolor='white')
    ax = fig.add_subplot(111, projection='3d')
    ax.view_init(elev=EL, azim=AZ)
    ax.set_xlim(-65, 65)
    ax.set_ylim(-58, 58)
    ax.set_zlim(0, 38)
    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')
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

    # ---- Frame generator ----
    def frame_generator():
        hold_frames = max(1, int(HOLD_T * FPS))
        final_frames = max(1, int(FINAL_T * FPS))

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
                    [0.0, t * zt])
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

    # Count total frames from generator (architecture review fix)
    frames_list = list(frame_generator())
    total_frames = len(frames_list)

    def update(frame_state):
        """No-op: all rendering happens in generator side-effects."""
        pass

    ani = FuncAnimation(fig, update, frames=frames_list,
                        save_count=total_frames, interval=1000/FPS,
                        blit=False, cache_frame_data=False)

    if save_path:
        writer = FFMpegWriter(fps=FPS, bitrate=1800)
        ani.save(save_path, writer=writer)
        print(f'MP4 saved: {save_path}')
    else:
        plt.show()
