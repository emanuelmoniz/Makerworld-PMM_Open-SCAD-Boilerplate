#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  STL bounding-sphere helper (shared)
# ------------------------------------------------------------
# Reads an STL (binary OR ascii) and prints
#     "<center-x> <center-y> <center-z> <radius>"
# -- the axis-aligned bounding-box center, and the radius of the sphere
# that circumscribes that box (half its diagonal).
#
# Used by scripts/render/render.sh to place the camera. OpenSCAD's own
# --autocenter/--viewall fits only the SMALLER of the image's two angular
# extents, so an elongated model rendered into a mismatched aspect ratio
# gets its long axis cropped. A sphere looks the same from every angle, so
# fitting the camera to it can never crop, at any azimuth/tilt.
#
# Replaces the original PowerShell-only reader, so the render pipeline no
# longer needs PowerShell or cygpath -- it runs on macOS/Linux too.
#
# Usage: stl_bbox.py <file.stl>             -> "cx cy cz radius"
#        stl_bbox.py --extents <file.stl>   -> "dx dy dz"  (used by the
#                                              smoke check's plate-size test)
# ============================================================
import math
import struct
import sys


def vertices(path):
    with open(path, "rb") as f:
        data = f.read()

    # A binary STL is exactly 84 + 50 * triangle_count bytes. Checking the
    # size is more reliable than checking for a leading "solid" keyword,
    # which some binary exporters also write into their 80-byte header.
    if len(data) >= 84:
        count = struct.unpack_from("<I", data, 80)[0]
        if len(data) == 84 + 50 * count:
            for i in range(count):
                base = 84 + 50 * i + 12  # skip the 12-byte normal
                for v in range(3):
                    yield struct.unpack_from("<fff", data, base + 12 * v)
            return

    for line in data.decode("utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[0] == "vertex":
            yield tuple(float(p) for p in parts[1:])


def main():
    args = sys.argv[1:]
    extents = bool(args) and args[0] == "--extents"
    if extents:
        args = args[1:]
    if len(args) != 1:
        print("Usage: stl_bbox.py [--extents] <file.stl>", file=sys.stderr)
        return 1

    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    for vx in vertices(args[0]):
        for axis in range(3):
            lo[axis] = min(lo[axis], vx[axis])
            hi[axis] = max(hi[axis], vx[axis])

    if lo[0] == math.inf:
        print(f"No geometry found in {args[0]}", file=sys.stderr)
        return 1

    if extents:
        print(f"{hi[0] - lo[0]:.3f} {hi[1] - lo[1]:.3f} {hi[2] - lo[2]:.3f}")
        return 0

    center = [(lo[a] + hi[a]) / 2 for a in range(3)]
    radius = 0.5 * math.sqrt(sum((hi[a] - lo[a]) ** 2 for a in range(3)))
    # Always dot-decimal: bash/awk on the other end cannot parse a comma.
    print(f"{center[0]:.6f} {center[1]:.6f} {center[2]:.6f} {radius:.6f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
