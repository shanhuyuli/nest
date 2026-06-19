"""Bird's Nest 3-stage animation using matplotlib."""
import os, sys
if 'DISPLAY' not in os.environ and 'WAYLAND_DISPLAY' not in os.environ:
    import matplotlib; matplotlib.use('Agg')
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, FFMpegWriter
from nest_geometry import compute_geometry

AZ, EL = -20, 25; FPS = 18; DT_GROW = 0.03; DT_RULE = 0.05
HOLD_T = 0.8; FINAL_T = 2.0

def run_animation(save_path=None):
    G = compute_geometry()
    pillars = G['pillars']; roof_segments = G['roof_segments']
    fig = plt.figure(figsize=(10,8), facecolor='white')
    ax = fig.add_subplot(111, projection='3d')
    ax.view_init(elev=EL, azim=AZ)
    ax.set_xlim(-65,65); ax.set_ylim(-58,58); ax.set_zlim(0,38)
    ax.set_xlabel('X'); ax.set_ylabel('Y'); ax.set_zlabel('Z')
    ax.set_title('Stage 0: Coordinate System')
    ax.plot(G['ellipse_outer'][0], G['ellipse_outer'][1], 0, '--', color='gray', lw=1)
    ax.plot(G['ellipse_inner'][0], G['ellipse_inner'][1], 0, ':', color='gray', lw=1)
    pl = [ax.plot([x,x],[y,y],[0,0],color='#BFBFBF',lw=3)[0] for x,y,_,_ in pillars]
    rl = [ax.plot([x1,x1],[y1,y1],[z1,z1],color='#EDB120',lw=2)[0] for (x1,y1,z1),(x2,y2,z2) in roof_segments]

    def gen():
        hf = max(1,int(HOLD_T*FPS)); ff = max(1,int(FINAL_T*FPS))
        for _ in range(hf): yield
        for i in range(len(pillars)):
            _,_,_,zt = pillars[i]; nf = max(1,int(DT_GROW*FPS))
            for fr in range(nf):
                t = (fr+1)/nf; pl[i].set_data_3d([pillars[i][0]]*2,[pillars[i][1]]*2,[0,t*zt]); yield
        ax.set_title('Stage 1: Pillars Complete')
        for _ in range(hf): yield
        for i in range(len(roof_segments)):
            (x1,y1,z1),(x2,y2,z2) = roof_segments[i]; nf = max(1,int(DT_RULE*FPS))
            for fr in range(nf):
                t = (fr+1)/nf
                rl[i].set_data_3d([x1,x1+t*(x2-x1)],[y1,y1+t*(y2-y1)],[z1,z1+t*(z2-z1)]); yield
        ax.set_title('Bird Nest: HP Ruled Surface')
        for _ in range(ff): yield

    frames = list(gen())
    ani = FuncAnimation(fig, lambda _:None, frames=frames, save_count=len(frames), interval=1000/FPS, cache_frame_data=False)
    if save_path:
        ani.save(save_path, writer=FFMpegWriter(fps=FPS, bitrate=1800)); print(f'MP4: {save_path}')
    else: plt.show()
