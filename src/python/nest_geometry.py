"""Bird's Nest hyperbolic paraboloid geometry engine.

Computes pillar positions and roof segments using the doubly-ruled
surface property of the hyperbolic paraboloid.

Parameters (prototype-verified):
    HP Surface:   z = C*(x^2/AHP^2 - y^2/BHP^2) + Z_OFFSET
    Outer ellipse boundary (ground projection): (x/A_OUT)^2 + (y/B_OUT)^2 = 1
    Inner ellipse boundary (roof opening):     (x/A_IN)^2  + (y/B_IN)^2  = 1
"""

import numpy as np

# ---- Global constants (prototype-verified) ----
AHP = 80.0
BHP = 72.0
C = 18.0
Z_OFFSET = 23.2
A_OUT = 60.0
B_OUT = 53.5
A_IN = 34.4
B_IN = 22.4
NU = 50
NV = 50
U_RANGE = (-1.06, 1.06)
V_RANGE = (-1.06, 1.06)


def hyperboloid_z(x, y):
    """HP surface height at (x, y)."""
    return C * (x**2 / AHP**2 - y**2 / BHP**2) + Z_OFFSET


def line_ellipse_intersect(m, d, a_ell, b_ell):
    """Intersection of line y = m*x + d with ellipse (x/a)^2 + (y/b)^2 = 1.

    Returns list of (x, y) tuples: 0, 1, or 2 points.
    """
    A = 1.0 / a_ell**2 + m**2 / b_ell**2
    B = 2.0 * m * d / b_ell**2
    Cc = d**2 / b_ell**2 - 1.0
    disc = B**2 - 4.0 * A * Cc

    if disc < 0.0:
        return []
    elif disc < 1e-12:
        x = -B / (2.0 * A)
        return [(x, m * x + d)]
    else:
        sqrt_disc = np.sqrt(disc)
        x1 = (-B + sqrt_disc) / (2.0 * A)
        x2 = (-B - sqrt_disc) / (2.0 * A)
        return [(x1, m * x1 + d), (x2, m * x2 + d)]


def point_in_ellipse(x, y, a_ell, b_ell):
    """True if (x, y) is strictly inside the ellipse."""
    return (x**2 / a_ell**2 + y**2 / b_ell**2) < 1.0


def _process_ruling(m, d, pillars, roof_segments):
    """Process one ruling line: intersect ellipses, connect valid segments."""
    pts_out = line_ellipse_intersect(m, d, A_OUT, B_OUT)
    pts_in = line_ellipse_intersect(m, d, A_IN, B_IN)

    all_pts = []  # list of (x, y, type, t_param)
    for (x, y) in pts_out:
        all_pts.append((x, y, 1, x))  # type=1: outer
    for (x, y) in pts_in:
        all_pts.append((x, y, 2, x))  # type=2: inner

    if len(all_pts) < 2:
        return

    all_pts.sort(key=lambda pt: pt[3])  # sort by t_param

    for j in range(len(all_pts) - 1):
        x1, y1, t1, _ = all_pts[j]
        x2, y2, t2, _ = all_pts[j + 1]

        if t1 == 2 and t2 == 2:
            continue  # skip inner-inner (inside opening)

        mid_x = (x1 + x2) / 2.0
        mid_y = (y1 + y2) / 2.0
        if point_in_ellipse(mid_x, mid_y, A_IN, B_IN):
            continue  # segment crosses the opening

        z1 = hyperboloid_z(x1, y1)
        z2 = hyperboloid_z(x2, y2)
        pillars.append((x1, y1, 0.0, z1))
        pillars.append((x2, y2, 0.0, z2))
        roof_segments.append(((x1, y1, z1), (x2, y2, z2)))


def compute_geometry():
    """Compute all nest geometry.

    Returns dict with:
        pillars:       np.ndarray [Nx4] (x, y, z_base, z_top)
        roof_segments: list of ((x1,y1,z1),(x2,y2,z2))
        ellipse_outer: np.ndarray [2x200]
        ellipse_inner: np.ndarray [2x200]
        u_count, v_count: int
    """
    pillars = []        # list of (x, y, z_base, z_top)
    roof_segments = []  # list of ((x1,y1,z1),(x2,y2,z2))

    slope_u = BHP / AHP    # +0.9
    slope_v = -BHP / AHP   # -0.9

    # ---- u-family: x/AHP - y/BHP = u ----
    u_vals = np.linspace(U_RANGE[0], U_RANGE[1], NU)
    for u in u_vals:
        d = -slope_u * AHP * u
        _process_ruling(slope_u, d, pillars, roof_segments)

    # ---- v-family: x/AHP + y/BHP = v ----
    v_vals = np.linspace(V_RANGE[0], V_RANGE[1], NV)
    for v in v_vals:
        d = -slope_v * AHP * v
        _process_ruling(slope_v, d, pillars, roof_segments)

    # ---- ellipse outlines ----
    theta = np.linspace(0.0, 2.0 * np.pi, 200)
    ellipse_outer = np.array([A_OUT * np.cos(theta), B_OUT * np.sin(theta)])
    ellipse_inner = np.array([A_IN * np.cos(theta), B_IN * np.sin(theta)])

    return {
        'pillars': np.array(pillars),
        'roof_segments': roof_segments,
        'ellipse_outer': ellipse_outer,
        'ellipse_inner': ellipse_inner,
        'u_count': NU,
        'v_count': NV,
    }
