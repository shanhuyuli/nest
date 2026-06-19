"""Bird's Nest hyperbolic paraboloid geometry engine."""
import numpy as np

AHP, BHP = 80.0, 72.0
C, Z_OFFSET = 18.0, 23.2
A_OUT, B_OUT = 60.0, 53.5
A_IN, B_IN = 34.4, 22.4
NU, NV = 50, 50
U_RANGE = (-1.06, 1.06)
V_RANGE = (-1.06, 1.06)

def hyperboloid_z(x, y):
    return C * (x**2/AHP**2 - y**2/BHP**2) + Z_OFFSET

def line_ellipse_intersect(m, d, a_ell, b_ell):
    A = 1.0/a_ell**2 + m**2/b_ell**2
    B = 2.0*m*d/b_ell**2
    Cc = d**2/b_ell**2 - 1.0
    disc = B**2 - 4.0*A*Cc
    if disc < 0: return []
    if disc < 1e-12:
        x = -B/(2.0*A)
        return [(x, m*x + d)]
    sd = np.sqrt(disc)
    return [((-B+sd)/(2*A), m*(-B+sd)/(2*A)+d), ((-B-sd)/(2*A), m*(-B-sd)/(2*A)+d)]

def point_in_ellipse(x, y, a_ell, b_ell):
    return (x**2/a_ell**2 + y**2/b_ell**2) < 1.0

def _process_ruling(m, d, pillars, roof_segments):
    pts_out = line_ellipse_intersect(m, d, A_OUT, B_OUT)
    pts_in  = line_ellipse_intersect(m, d, A_IN, B_IN)
    all_pts = []
    for (x,y) in pts_out: all_pts.append((x,y,1,x))
    for (x,y) in pts_in: all_pts.append((x,y,2,x))
    if len(all_pts) < 2: return
    all_pts.sort(key=lambda p: p[3])
    for j in range(len(all_pts)-1):
        x1,y1,t1,_ = all_pts[j]; x2,y2,t2,_ = all_pts[j+1]
        if t1==2 and t2==2: continue
        mx,my = (x1+x2)/2,(y1+y2)/2
        if point_in_ellipse(mx,my,A_IN,B_IN): continue
        z1,z2 = hyperboloid_z(x1,y1), hyperboloid_z(x2,y2)
        pillars.append((x1,y1,0.0,z1)); pillars.append((x2,y2,0.0,z2))
        roof_segments.append(((x1,y1,z1),(x2,y2,z2)))

def compute_geometry():
    pillars = []; roof_segments = []
    slope_u, slope_v = BHP/AHP, -BHP/AHP
    for u in np.linspace(U_RANGE[0], U_RANGE[1], NU):
        _process_ruling(slope_u, -slope_u*AHP*u, pillars, roof_segments)
    for v in np.linspace(V_RANGE[0], V_RANGE[1], NV):
        _process_ruling(slope_v, -slope_v*AHP*v, pillars, roof_segments)
    theta = np.linspace(0, 2*np.pi, 200)
    return {'pillars': np.array(pillars), 'roof_segments': roof_segments,
            'ellipse_outer': np.array([A_OUT*np.cos(theta), B_OUT*np.sin(theta)]),
            'ellipse_inner': np.array([A_IN*np.cos(theta), B_IN*np.sin(theta)]),
            'u_count': NU, 'v_count': NV}
