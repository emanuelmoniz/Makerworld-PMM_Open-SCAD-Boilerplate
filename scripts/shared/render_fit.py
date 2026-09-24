#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Tight camera fit for one render view (shared)
# ------------------------------------------------------------
# For RENDER_FIT="tight" (scripts/render_config.sh): fits the camera to the
# model's actual outline as seen from ONE perspective, instead of to the
# sphere around its bounding box (stl_bbox.py, RENDER_FIT="sphere"). The
# sphere never crops at any angle but leaves a tall or long model small in
# the frame; this fills the frame up to RENDER_MARGIN.
#
# How: every mesh vertex is taken into OpenSCAD's view space and the
# screen-space extents give the target (the point that lands at the image
# center) and the distance. View space, as OpenSCAD's --camera / $vpr use
# it: rot = [0, 0, 0] is the TOP view, and a rotation turns the camera, so
# the scene turns by the inverse, Rx(-rot_x) . Ry(-rot_y) . Rz(-rot_z);
# screen right is then view +X and screen up is view +Y. (Established by
# rendering: with it every fit comes out centered, at both azimuths
# render.sh uses; any other sign or axis choice does not.)
# With the orthographic projection render.sh
# uses, the visible half height is distance * tan(fov / 2) and the half
# width is that times the aspect ratio -- the same relation the sphere fit
# relies on.
#
# Usage: render_fit.py <file.stl> <rot_x> <rot_y> <rot_z> <fov_deg> <aspect_w_over_h> <margin>
#        -> "tx ty tz distance"
# ============================================================
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stl_bbox import vertices  # noqa: E402


def rotation(rx, ry, rz):
    """3x3 matrix of Rx(rx) @ Ry(ry) @ Rz(rz) (degrees)."""
    cx, sx = math.cos(math.radians(rx)), math.sin(math.radians(rx))
    cy, sy = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    cz, sz = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Rx, Ry), Rz)


def main():
    if len(sys.argv) != 8:
        print(__doc__ or "usage: render_fit.py <stl> <rx> <ry> <rz> <fov> <aspect> <margin>",
              file=sys.stderr)
        return 1
    path = sys.argv[1]
    rx, ry, rz, fov, aspect, margin = (float(a) for a in sys.argv[2:])

    pts = set(vertices(path))
    if not pts:
        print(f"No geometry found in {path}", file=sys.stderr)
        return 1
    R = rotation(-rx, -ry, -rz)      # world -> view (see header)
    us = [R[0][0] * x + R[0][1] * y + R[0][2] * z for x, y, z in pts]   # screen right
    vs = [R[1][0] * x + R[1][1] * y + R[1][2] * z for x, y, z in pts]   # screen up
    umin, umax, vmin, vmax = min(us), max(us), min(vs), max(vs)

    # Screen-space center, mapped back to world space (depth 0): R is
    # orthonormal, so its inverse is its transpose.
    du, dv = (umin + umax) / 2, (vmin + vmax) / 2
    target = [R[0][i] * du + R[1][i] * dv for i in range(3)]

    t = math.tan(math.radians(fov) / 2)
    half_w, half_h = (umax - umin) / 2, (vmax - vmin) / 2
    distance = max(half_h / t, half_w / (t * aspect)) * (1 + margin)
    distance = max(distance, 1e-3)
    # Always dot-decimal: bash/awk on the other end cannot parse a comma.
    print(f"{target[0]:.6f} {target[1]:.6f} {target[2]:.6f} {distance:.6f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
