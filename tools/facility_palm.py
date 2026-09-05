"""Independent complete-source FACILITY palm reference (no scene state)."""
from collections import deque


def build(sp):
    assert (sp['W'], sp['H']) == (16, 32)
    # Follow nonblack border-connected regions, independently of the generic
    # building mask (which treats dark shades as a boundary).
    reachable = set()
    pending = deque()
    for y in range(32):
        for x in range(16):
            if (x in (0, 15) or y in (0, 31)) and sp['col'][y][x] != 3:
                reachable.add((x, y))
                pending.append((x, y))
    while pending:
        x, y = pending.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (0 <= nx < 16 and 0 <= ny < 32 and (nx, ny) not in reachable
                    and sp['col'][ny][nx] != 3):
                reachable.add((nx, ny))
                pending.append((nx, ny))
    mask = {(x, y) for y in range(32) for x in range(16)
            if (x, y) not in reachable}
    assert mask
    last = max(y for x, y in mask)
    back = (last // 8) * 8 + 1.5
    return {(x, last - y, back + d): (sp['col'][y][x], sp['src'][y][x])
            for x, y in mask for d in range(5)}
