"""Independent planar reference for Bill's original metal connecting pipe.

The octagonal surface uses no additional voxel skin. Its two collars derive
from the endpoint artwork; the long center strip stays a smooth tube.
"""
from math import floor, sqrt


def build(sp, t):
    variant = t["pipe_variant"]
    assert variant in ("link", "left", "right")
    assert (sp["W"], sp["H"]) == ((48 if variant == "link" else 8), 16)
    if variant == "link":
        grey, white, dark, black = (8, 6), (8, 7), (8, 10), (8, 5)
    else:
        grey, white, dark, black = (4, 3), (4, 6), (4, 10), (4, 2)
    for donor, color in zip((grey, white, dark, black), (1, 0, 2, 3)):
        x, y = donor
        assert sp["col"][y][x] == color and not sp["out"][y][x]

    # Interpret the nine-pixel tube and eleven-pixel cuff elevations as
    # actual octagonal cross-sections, with their original8.5px center.
    # Its depth axis aligns with the accepted chamber center at world32.
    k = sqrt(2) - 1
    ring = ((1, k), (k, 1), (-k, 1), (-1, k),
            (-1, -k), (-k, -1), (k, -1), (1, -k))
    materials = (white, white, grey, dark, dark, grey, grey, grey)
    xmin, xmax, collars = {
        "link": (-4, 52, ((4, 7), (41, 44))),
        "left": (0, 12, ((1, 4),)),
        "right": (-4, 8, ((4, 7),)),
    }[variant]
    stations = {xmin, xmax}
    for a, b in collars:
        stations.update((a, a + .35, b - .35, b))
    # Rendering uses the shared8px world-curvature lattice. Intermediate
    # stations add no collars and do not alter the source-metal pattern.
    stations.update(range((floor(xmin / 8) + 1) * 8, xmax, 8))
    stations = sorted(stations)
    sections = []
    for a, b in zip(stations, stations[1:]):
        mid = (a + b) / 2
        cuff = next(((lo, hi) for lo, hi in collars if lo < mid < hi), None)
        radius = 5.5 if cuff else 4.5
        band = bool(cuff and (mid < cuff[0] + .35 or mid > cuff[1] - .35))
        sections.append((a, b, radius, band))

    def point(x, r, j):
        dy, dz = ring[j % 8]
        return (x, 8.5 + r * dy, 16 + r * dz)

    faces = []

    def face(points, source, shade):
        faces.append(dict(points=points, source=source, shade=shade))

    previous = None
    for a, b, radius, band in sections:
        if previous is not None and previous != radius:
            for j in range(8):
                face([point(a, previous, j), point(a, previous, j + 1),
                      point(a, radius, j + 1), point(a, radius, j)], black, .75)
        for j in range(8):
            ny = ring[j][0] + ring[(j + 1) % 8][0]
            nz = ring[j][1] + ring[(j + 1) % 8][1]
            length = sqrt(ny * ny + nz * nz)
            shade = .68 + .27 * max(0, ny / length) + .1 * max(0, nz / length)
            face([point(a, radius, j), point(a, radius, j + 1),
                  point(b, radius, j + 1), point(b, radius, j)],
                 black if band else materials[j], shade)
        previous = radius

    # Four ordinary quads close each end; all vertices are distinct.
    for left, x in ((True, xmin), (False, xmax)):
        for j in range(0, 8, 2):
            vertices = [point(x, 4.5, n) for n in range(j, j + 3)]
            if left:
                vertices.reverse()
            face([(x, 8.5, 16)] + vertices, dark if left else grey,
                 .68 if left else .78)
    return faces
