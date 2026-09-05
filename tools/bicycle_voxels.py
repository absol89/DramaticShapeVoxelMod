"""Independent offline surface reconstruction for the two original CLUB bikes.

The assembly is expressed as measured ring sections, closed rods and boxes.
It does not load the Lua runtime, image generator, or any exported candidate
surfaces. World-curve clipping is applied to the resulting planar polygons.
"""
from math import sin, cos, pi, sqrt, floor


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, k): return tuple(x * k for x in a)
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a, 1 / sqrt(dot(a, a)))


def _cut(polygon, axis, bound, positive):
    result = []
    for a, b in zip(polygon[-1:] + polygon[:-1], polygon):
        da, db = a[axis] - bound, b[axis] - bound
        if not positive: da, db = -da, -db
        if (da >= -1e-8) != (db >= -1e-8):
            fraction = (bound-a[axis])/(b[axis]-a[axis])
            p = list(add(a, mul(sub(b, a), fraction))); p[axis] = bound
            result.append(tuple(p))
        if db >= -1e-8: result.append(b)
    clean = []
    for p in result:
        if not clean or dot(sub(p, clean[-1]), sub(p, clean[-1])) > 1e-14: clean.append(p)
    if len(clean) > 1 and dot(sub(clean[0], clean[-1]), sub(clean[0], clean[-1])) < 1e-14: clean.pop()
    return clean


class Assembly:
    def __init__(self): self.faces, self.component = [], None

    def face(self, polygon, source):
        normal = unit(cross(sub(polygon[1], polygon[0]), sub(polygon[2], polygon[0])))
        shade = .68 + .23*max(0, normal[1]) + .09*max(0, normal[2])
        polygons = [polygon]
        for axis in (0, 2):
            lo, hi = min(p[axis] for p in polygon), max(p[axis] for p in polygon)
            bounds = range((floor(lo/8)+1)*8, int(hi)+9, 8)
            for bound in bounds:
                if bound >= hi-1e-8: break
                split = []
                for poly in polygons:
                    if min(p[axis] for p in poly) < bound-1e-8 and max(p[axis] for p in poly) > bound+1e-8:
                        split.extend(q for q in (_cut(poly, axis, bound, False), _cut(poly, axis, bound, True)) if len(q) >= 3)
                    else: split.append(poly)
                polygons = split
        for poly in polygons:
            if len(poly) == 4:
                u = cross(sub(poly[1], poly[0]), sub(poly[2], poly[0]))
                v = cross(sub(poly[2], poly[0]), sub(poly[3], poly[0]))
                if dot(u, u) > 1e-14 and dot(v, v) > 1e-14 and dot(u, v) > 0:
                    self.faces.append(dict(points=poly, source=source, shade=shade, component=self.component)); continue
            for j in range(1, len(poly)-1):
                a, b, c = poly[0], poly[j], poly[j+1]
                normal = cross(sub(b, a), sub(c, a))
                if dot(normal, normal) > 1e-14:
                    self.faces.append(dict(points=[a, b, mul(add(b,c), .5), c], source=source, shade=shade, component=self.component))

    def box(self, lo, hi, color, top=None):
        # Six faces of a closed Cartesian solid. Indices wind outward.
        x,y,z=lo; X,Y,Z=hi
        points=((x,y,z),(X,y,z),(X,y,Z),(x,y,Z),(x,Y,z),(X,Y,z),(X,Y,Z),(x,Y,Z))
        for indices in ((0,3,7,4),(2,1,5,6),(1,0,4,5),(3,2,6,7),(0,1,2,3),(7,6,5,4)):
            self.face([points[k] for k in indices], top if indices==(7,6,5,4) and top is not None else color)

    def rod(self, a, b, radius, color, sides=6):
        axis=unit(sub(b,a)); reference=(1,0,0) if abs(axis[1])>.9 else (0,1,0)
        u=unit(cross(axis, reference)); v=cross(axis,u)
        rings=[]
        for center in (a,b):
            rings.append([add(center,mul(add(mul(u,cos(j*2*pi/sides)),mul(v,sin(j*2*pi/sides))),radius)) for j in range(sides)])
        near,far=rings
        for j in range(sides): self.face([near[j],near[(j+1)%sides],far[(j+1)%sides],far[j]],color)
        for j in range(0,sides,2):
            self.face([a,near[(j+2)%sides],near[(j+1)%sides],near[j]],color)
            self.face([b,far[j],far[(j+1)%sides],far[(j+2)%sides]],color)


def build(sp, t):
    variant=t['bicycle']; assert variant in ('wall','floor')
    assert (sp['W'],sp['H'])==(24,16)
    wall=variant=='wall'
    black,dark,grey,white=((3,8),(4,13),(4,5),(3,5)) if wall else ((8,4),(3,8),(4,13),(12,4))
    for color,(x,y) in zip((3,2,1,0),(black,dark,grey,white)):
        assert sp['col'][y][x]==color and not sp['out'][y][x]
    z=20 if wall else 12
    a=Assembly()
    for cx in (4.5,19.5):
        a.component='tire_'+str(cx)
        def point(radius, angle, zz): return (cx+radius*cos(angle),4.5+radius*sin(angle),zz)
        for j in range(12):
            theta,phi=j*2*pi/12,(j+1)*2*pi/12
            a.face([point(4.5,theta,z-.7),point(4.5,phi,z-.7),point(4.5,phi,z+.7),point(4.5,theta,z+.7)],black)
            a.face([point(3.5,theta,z+.7),point(3.5,phi,z+.7),point(3.5,phi,z-.7),point(3.5,theta,z-.7)],grey)
            a.face([point(4.5,theta,z+.7),point(4.5,phi,z+.7),point(3.5,phi,z+.7),point(3.5,theta,z+.7)],black)
            a.face([point(4.5,phi,z-.7),point(4.5,theta,z-.7),point(3.5,theta,z-.7),point(3.5,phi,z-.7)],black)
        a.component='spokes_'+str(cx)
        for j in range(3):
            dx,dy=3.5*cos(j*pi/3),3.5*sin(j*pi/3)
            a.rod((cx-dx,4.5-dy,z),(cx+dx,4.5+dy,z),.1,white,4)
        a.rod((cx,4.5,z-.85),(cx,4.5,z+.85),.42,grey)
    front,rear,crank,head,seat=(4.5,4.5,z),(19.5,4.5,z),(12.5,4,z),(8.5,11,z),(14,10.5,z)
    a.component='frame'
    for start,end in ((head,seat),(head,crank),(seat,crank),(seat,rear),(rear,crank)): a.rod(start,end,.36,grey)
    for direction in (-1,1):
        a.rod((head[0],head[1],z+direction*.45),(front[0],front[1],z+direction*.85),.22,dark)
        a.rod((seat[0],seat[1],z+direction*.35),(rear[0],rear[1],z+direction*.85),.2,dark)
    a.component='saddle';a.rod(crank,(14,12,z),.25,dark)
    a.box((12,11.7,z-1.6),(16,12.25,z+1.6),black,grey)
    a.box((12.4,12.25,z-1.25),(15.6,12.5,z+1.25),grey)
    a.component='handlebars';a.rod(head,(8.5,15,z),.28,dark)
    a.rod((8.5,15,z-2.7),(8.5,15,z+2.7),.22,white)
    for direction in (-1,1):a.rod((8.5,15,z+direction*2.1),(9.5,15,z+direction*3),.27,black)
    a.component='crank_pedals';a.rod((12.5,4,z-1.35),(12.5,4,z+1.35),.38,dark)
    a.rod((12.5,4,z+1.35),(11.6,3.2,z+1.35),.16,white,4)
    a.rod((12.5,4,z-1.35),(13.4,4.8,z-1.35),.16,white,4)
    a.box((11.1,3,z+1.1),(12.1,3.35,z+2),(black))
    a.box((12.9,4.65,z-2),(13.9,5,z-1.1),black)
    a.component='stand';a.rod((12.5,4,z+.5),(13.1,.18,z+2.35),.17,dark,4)
    if wall:
        a.component='basket';x0,x1,z0,z1=2,7.8,z-2.4,z+2.4
        a.box((x0,10.2,z0),(x1,10.6,z1),grey)
        for y in (11.8,14.8):
            for lo,hi in (((x0,y,z0),(x1,y+.25,z0+.25)),((x0,y,z1-.25),(x1,y+.25,z1)),((x0,y,z0),(x0+.25,y+.25,z1)),((x1-.25,y,z0),(x1,y+.25,z1))):a.box(lo,hi,white)
        for x in (x0,4,6,x1-.25):
            a.box((x,10.6,z0),(x+.25,14.8,z0+.25),grey)
            a.box((x,10.6,z1-.25),(x+.25,14.8,z1),grey)
        for zz in (z-1.2,z+1.2):a.box((x0,10.6,zz),(x0+.25,14.8,zz+.25),grey)
        a.rod((7.8,11,z),(8.5,12,z),.23,dark,4)
    return a.faces
