"""Unit tests for nest_geometry.py (Iteration 2)."""
import pytest
import numpy as np
from nest_geometry import (
    hyperboloid_z, line_ellipse_intersect,
    point_in_ellipse, compute_geometry,
    A_OUT, B_OUT,
)


class TestHyperboloidZ:
    def test_at_origin(self):
        assert hyperboloid_z(0, 0) == pytest.approx(23.2)

    def test_at_major_axis_end(self):
        z = hyperboloid_z(A_OUT, 0)
        assert z == pytest.approx(33.325, rel=1e-4)

    def test_at_minor_axis_end(self):
        z = hyperboloid_z(0, B_OUT)
        assert z == pytest.approx(13.262, rel=1e-4)


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

    def test_output_structure(self):
        G = compute_geometry()
        assert 'pillars' in G
        assert 'roof_segments' in G
        assert 'ellipse_outer' in G
        assert 'ellipse_inner' in G
        assert 'u_count' in G
        assert 'v_count' in G
        assert G['u_count'] == 50
        assert G['v_count'] == 50
        assert G['pillars'].shape[1] == 4
        assert len(G['roof_segments']) == 144
        assert G['ellipse_outer'].shape == (2, 200)
