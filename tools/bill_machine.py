"""Independent source-texel model for Bill's opt-in cell-separator chamber.

The caller supplies the composed 32x40 sprite produced by building_voxels.
This module changes neither source data nor interaction/collision state.
"""
from math import floor


def build(sp):
    assert (sp["W"], sp["H"]) == (32, 40)
    palette, uv = sp["col"], sp["src"]
    samples = {}

    def source(sx, sy):
        return palette[sy][sx], uv[sy][sx]

    metal = source(7, 21)
    shadow = source(2, 16)
    outline = source(0, 16)
    assert (metal[0], shadow[0], outline[0]) == (1, 2, 3)

    def rounded(v):
        return floor(v + 0.5)

    def included(x, z, radius):
        return (x - 15.5) ** 2 + (z - 15.5) ** 2 <= radius ** 2

    cap_spans = (
        (12, 19), (9, 22), (6, 25), (4, 27), (3, 28), (2, 29),
        (1, 30), (1, 30), (0, 31), (0, 31), (0, 31), (0, 31),
        (0, 31), (1, 30), (1, 30), (2, 29), (3, 28), (5, 26),
        (7, 24), (9, 22), (12, 19),
    )
    # First materialize cross-sections independently of the elevation
    # passes; this also states the exact two-pixel mounting overhang.
    foot = {(x, z) for x in range(32) for z in range(32)
            if included(x, z, 16)}
    barrel = {(x, z) for x in range(32) for z in range(32)
              if included(x, z, 14)}
    boundary = {(x, z) for x, z in foot
                if any(p not in foot for p in
                       ((x - 1, z), (x + 1, z), (x, z - 1), (x, z + 1)))}
    for x, z in foot:
        for y in range(3):
            samples[x, y, z + 8] = outline if y == 0 or (x, z) in boundary else shadow
        row = rounded(z * 20 / 31)
        while not cap_spans[row][0] <= x <= cap_spans[row][1]:
            row += 1 if row < 10 else -1
        texel = outline if (x, z) in boundary else source(x, row)
        samples[x, 30, z + 8] = texel
        if ((x - 15.5) ** 2 + (z - 15.5) ** 2 >= 196
                or (x - 15.5) ** 2 + (z - 12) ** 2 <= 25):
            samples[x, 31, z + 8] = texel

    base_arc = ((0, 31), (1, 30), (1, 30), (2, 29), (3, 28),
                (4, 27), (6, 25), (9, 22), (12, 19))
    body_ranges = {
        x: (1 + max(row for row, (lo, hi) in enumerate(cap_spans) if lo <= x <= hi),
            31 + max(row for row, (lo, hi) in enumerate(base_arc) if lo <= x <= hi))
        for x in range(32)
    }

    def body_row(sx, height):
        first, last = body_ranges[sx]
        return rounded(first + (last - first) * (29 - height) / 26)

    for y in range(3, 30):
        for x, z in barrel:
            if z < 15.5:
                texel = shadow if y in (3, 29) else metal
            else:
                sx = max(0, min(31, rounded((x - 2) * 31 / 27)))
                sy = body_row(sx, y)
                texel = source(sx, sy)
            samples[x, y, z + 8] = texel

    latch = {21: (13, 18), 22: (12, 19), 23: (11, 20), 24: (11, 20),
             25: (11, 20), 26: (11, 20), 27: (11, 20),
             28: (12, 19), 29: (13, 18)}
    front = {x: max(z for xx, z in barrel if xx == x)
             for x in range(2, 30)}
    for x, z in front.items():
        sx = max(0, min(31, rounded((x - 2) * 31 / 27)))
        for y in range(3, 30):
            sy = body_row(sx, y)
            if sy in latch and latch[sy][0] <= sx <= latch[sy][1]:
                for extension in (1, 2):
                    front_z = z + extension
                    if front_z <= 31 and (x, front_z) in foot:
                        samples[x, y, front_z + 8] = source(sx, sy)
    # Inferred front access: clear the complete original Bill sprite's
    # width/height, including its floor-level scripted first exit frame.
    # The rear of the recess wears the machine's own shadow material.
    for x in range(8, 24):
        for y in range(18):
            for z in range(31, 40):
                samples.pop((x, y, z), None)
            samples[x, y, 30] = shadow
    return samples
