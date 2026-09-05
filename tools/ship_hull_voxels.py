"""Offline source/geometry reference for the faceted S.S. Anne remaster.

The current exterior is an analytic surface model, not a second voxel skin.
This independent Python implementation reconstructs each authored component,
clips convex facets to the terrain lattice, and returns the standard source
coordinate / shade surface records used by the furniture authoring tools.
The dynamic ship pose, map ownership and departure code remains Lua-only.
"""
from math import sin, cos, pi, sqrt, floor, ceil
from collections import Counter
WIDTH, DEPTH, EPS = 128, 48, 1e-7
STATIONS=((0,23),(4,15),(12,8),(24,4),(40,1),(56,0),(64,0),(80,0),(96,1),(112,4),(122,8),(128,14))
WHITE,GREY,DARK,BLACK=(62,4),(60,18),(50,1),(64,47)

def mix(a,b,t):return tuple(a[k]+(b[k]-a[k])*t for k in range(3))
def normal(a,b,c):
    u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
    return (u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
def norm(a):return sqrt(sum(v*v for v in a))
def clip(poly,axis,edge,below):
    out=[];a=poly[-1];ain=a[axis]<=edge+EPS if below else a[axis]>=edge-EPS
    for b in poly:
        bin_=b[axis]<=edge+EPS if below else b[axis]>=edge-EPS
        if ain!=bin_:
            p=list(mix(a,b,(edge-a[axis])/(b[axis]-a[axis])));p[axis]=edge;out.append(tuple(p))
        if bin_:out.append(tuple(b))
        a,ain=b,bin_
    clean=[]
    for p in out:
        if not clean or sum(abs(p[k]-clean[-1][k]) for k in range(3))>EPS:clean.append(p)
    if len(clean)>1 and sum(abs(clean[0][k]-clean[-1][k]) for k in range(3))<EPS:clean.pop()
    return clean

def build_surfaces():
    faces=[]
    def face(poly,source,role,outward):
        n=normal(*poly[:3]);length=norm(n)
        if length<EPS:return
        if sum(n[k]*outward[k] for k in range(3))<0:
            poly=list(reversed(poly));n=normal(*poly[:3]);length=norm(n)
        shade=.69+.23*max(0,n[1]/length)+.08*max(0,n[2]/length)
        pieces=[poly]
        for axis in range(3):
            next_pieces=[]
            for part in pieces:
                lo=min(p[axis] for p in part);hi=max(p[axis] for p in part)
                remaining=part;edge=(floor((lo+EPS)/8)+1)*8
                while edge<hi-EPS:
                    a=clip(remaining,axis,edge,True);remaining=clip(remaining,axis,edge,False)
                    if len(a)>=3:next_pieces.append(a)
                    edge+=8
                if len(remaining)>=3:next_pieces.append(remaining)
            pieces=next_pieces
        def put(a,b,c,d):
            if norm(normal(a,b,c))<EPS or norm(normal(a,c,d))<EPS:return
            faces.append(dict(points=[a,b,c,d],source=source,shade=shade,role=role))
        for part in pieces:
            if len(part)==4:put(*part)
            else:
                for i in range(1,len(part)-1):
                    a,b,c=part[0],part[i],part[i+1];put(a,b,mix(b,c,.5),c)
    def quad(a,b,c,d,source,role,outward):face([a,b,c,d],source,role,outward)
    def box(x0,x1,y0,y1,z0,z1,source,role,top=None):
        quad((x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0),source,role,(0,0,-1))
        quad((x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1),source,role,(0,0,1))
        quad((x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0),source,role,(-1,0,0))
        quad((x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1),source,role,(1,0,0))
        quad((x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0),top or source,role,(0,1,0))
    outline=list(STATIONS)+[(x,48-z) for x,z in reversed(STATIONS)]
    def point(p,y,sx,sz):return (64+(p[0]-64)*sx,y,24+(p[1]-24)*sz)
    bands=((0,.94,.66,DARK),(4,.98,.80,DARK),(6,1,.86,BLACK),(8,1,.90,WHITE),(16,1,1,WHITE),(18,1,1,WHITE),(19,1,1,BLACK),(20,1,1,GREY))
    for a,b in zip(bands,bands[1:]):
        for j,p in enumerate(outline):
            q=outline[(j+1)%len(outline)]
            portal=p[1]==0 and q[1]==0 and p[0]>=64 and q[0]<=80
            def band(y0,y1):
                t0=(y0-a[0])/(b[0]-a[0]);t1=(y1-a[0])/(b[0]-a[0])
                ax,az=a[1]+(b[1]-a[1])*t0,a[2]+(b[2]-a[2])*t0
                bx,bz=a[1]+(b[1]-a[1])*t1,a[2]+(b[2]-a[2])*t1
                A,B,C,D=point(p,y0,ax,az),point(q,y0,ax,az),point(q,y1,bx,bz),point(p,y1,bx,bz)
                outward=((p[0]+q[0])/2-64,0,(p[1]+q[1])/2-24)
                face([A,B,C],b[3],'hull',outward);face([A,C,D],b[3],'hull',outward)
            if portal:
                if a[0]<2:band(a[0],min(2,b[0]))
                if b[0]>18:band(max(18,a[0]),b[0])
            else:band(a[0],b[0])
    for a,b in zip(STATIONS,STATIONS[1:]):
        quad((a[0],20,a[1]),(a[0],20,48-a[1]),(b[0],20,48-b[1]),(b[0],20,b[1]),GREY,'deck',(0,1,0))
    box(64,80,0,2,0,10,DARK,'boarding-floor',GREY)
    quad((64,2,0),(64,18,0),(64,18,10),(64,2,10),WHITE,'boarding-jamb',(1,0,0))
    quad((80,2,0),(80,2,10),(80,18,10),(80,18,0),WHITE,'boarding-jamb',(-1,0,0))
    quad((64,2,10),(64,18,10),(80,18,10),(80,2,10),BLACK,'boarding-back',(0,0,-1))
    quad((64,18,0),(80,18,0),(80,18,10),(64,18,10),WHITE,'boarding-soffit',(0,-1,0))
    def cabin(x0,x1,y0,y1,z0,z1,b,role):
        poly=((x0+b,z0),(x1-b,z0),(x1,z0+b),(x1,z1-b),(x1-b,z1),(x0+b,z1),(x0,z1-b),(x0,z0+b))
        for j,p in enumerate(poly):
            q=poly[(j+1)%len(poly)];dx,dz=q[0]-p[0],q[1]-p[1];span=sqrt(dx*dx+dz*dz)
            count=max(1,floor(span/6));outward=(dz,0,-dx)
            for k in range(count):
                f0,f1=k/count,(k+1)/count;a=(p[0]+dx*f0,p[1]+dz*f0);c=(p[0]+dx*f1,p[1]+dz*f1)
                def wall(v0,v1,lo,hi,mat):
                    a0,a1=a[0]+(c[0]-a[0])*v0,a[1]+(c[1]-a[1])*v0
                    b0,b1=a[0]+(c[0]-a[0])*v1,a[1]+(c[1]-a[1])*v1
                    quad((a0,lo,a1),(b0,lo,b1),(b0,hi,b1),(a0,hi,a1),mat,role,outward)
                wall(0,1,y0,y0+2,WHITE);wall(0,1,y1-1,y1,WHITE)
                wall(0,.14,y0+2,y1-1,WHITE);wall(.86,1,y0+2,y1-1,WHITE)
                wall(.14,.86,y0+2,y0+3,DARK);wall(.14,.86,y0+3,y1-2,BLACK);wall(.14,.86,y1-2,y1-1,GREY)
        center=((x0+x1)/2,y1,(z0+z1)/2)
        for j,p in enumerate(poly):
            q=poly[(j+1)%len(poly)];face([center,(p[0],y1,p[1]),(q[0],y1,q[1])],GREY,role+'-roof',(0,1,0))
    cabin(38,111,20,31,12,36,3,'cabin');box(37,112,31,32,11,37,WHITE,'cabin-eave',GREY)
    cabin(37,57,32,39,17,31,2,'bridge');box(36,58,39,40,16,32,WHITE,'bridge-eave',GREY)
    def beam(a,b,r,source,role):
        dx,dz=b[0]-a[0],b[2]-a[2];d=sqrt(dx*dx+dz*dz)
        if d<EPS:return
        nx,nz=-dz/d*r,dx/d*r
        p=((a[0]+nx,a[1]-r,a[2]+nz),(b[0]+nx,b[1]-r,b[2]+nz),(b[0]-nx,b[1]-r,b[2]-nz),(a[0]-nx,a[1]-r,a[2]-nz))
        t=[(q[0],q[1]+2*r,q[2]) for q in p]
        for j in range(4):
            k=(j+1)%4;quad(p[j],p[k],t[k],t[j],source,role,((p[j][0]+p[k][0]-a[0]-b[0])/2,0,(p[j][2]+p[k][2]-a[2]-b[2])/2))
        quad(t[0],t[3],t[2],t[1],source,role,(0,1,0))
    for j,p in enumerate(outline):
        q=outline[(j+1)%len(outline)]
        a=(64+(p[0]-64)*.982,20,24+(p[1]-24)*.955);b=(64+(q[0]-64)*.982,20,24+(q[1]-24)*.955)
        span=sqrt((b[0]-a[0])**2+(b[2]-a[2])**2);count=max(1,ceil(span/8))
        for k in range(count):
            f=k/count;x,z=a[0]+(b[0]-a[0])*f,a[2]+(b[2]-a[2])*f
            box(x-.33,x+.33,20,25,z-.33,z+.33,WHITE,'rail-post')
        for y in (22.25,24.7):beam((a[0],y,a[2]),(b[0],y,b[2]),.25,WHITE,'rail')
    def ring(cx,cz,y,rx,rz,n,lean=0):return [(cx+cos(2*pi*j/n)*rx+lean,y,cz+sin(2*pi*j/n)*rz) for j in range(n)]
    def loft(a,b,source,role,inside=False):
        for j,p in enumerate(a):
            k=(j+1)%len(a);q=a[k]
            n=((p[0]+q[0])/2-(a[0][0]+a[len(a)//2][0])/2,0,(p[2]+q[2])/2-(a[0][2]+a[len(a)//2][2])/2)
            if inside:n=tuple(-v for v in n)
            quad(p,q,b[k],b[j],source,role,n)
    for cx in (70,89):
        base=ring(cx,24,32,6,5,12);lower=ring(cx,24,34,5,4,12);upper=ring(cx,24,52,4.5,3.7,12,1.5);lip=ring(cx,24,55,5.1,4.3,12,1.5)
        loft(base,lower,WHITE,'funnel-base');loft(lower,upper,GREY,'funnel');loft(upper,lip,BLACK,'funnel-cap')
        mouth=ring(cx,24,55,3.6,2.8,12,1.5);bottom=ring(cx,24,49,3.6,2.8,12,1.5)
        for j,p in enumerate(lip):
            k=(j+1)%12;quad(p,lip[k],mouth[k],mouth[j],BLACK,'funnel-rim',(0,1,0))
        loft(mouth,bottom,DARK,'funnel-inside',True)
        for j in range(0,12,2):quad((cx+1.5,49,24),bottom[j],bottom[(j+1)%12],bottom[(j+2)%12],BLACK,'funnel-floor',(0,1,0))
    for cx in (72,97):
        box(cx-5,cx-4,20,24,38.5,42,BLACK,'boat-support');box(cx+4,cx+5,20,24,38.5,42,BLACK,'boat-support')
        lower=ring(cx,40.2,24,6.5,1.4,12);rim=ring(cx,40.2,27,8,3,12);cover=ring(cx,40.2,28,6,1.9,12)
        loft(lower,rim,WHITE,'lifeboat');loft(rim,cover,GREY,'lifeboat-cover')
        for j in range(0,12,2):quad((cx,28.8,40.2),cover[j],cover[(j+1)%12],cover[(j+2)%12],WHITE,'lifeboat-lid',(0,1,0))
        for x in (cx-3,cx+3):beam((x,28.1,38.7),(x,28.1,41.7),.12,DARK,'lifeboat-strap')
    for side in (-1,1):
        for x in (28,40,52,88,100,112):
            def hull_z(px,py,offset):
                a,b=next((a,b) for a,b in zip(STATIONS,STATIONS[1:]) if a[0]<=px<=b[0])
                u,v=(px-a[0])/(b[0]-a[0]),(py-8)/8
                A,B,C,D=24+(a[1]-24)*.9,24+(b[1]-24)*.9,b[1],a[1]
                north=A+u*(B-A)+v*(C-B) if u>=v else A+u*(C-D)+v*(D-A)
                return 24+side*(24-north)+side*offset
            outer=[];inner=[]
            for j in range(8):
                angle=2*pi*j/8;ox,oy=x+1.5*cos(angle),13+1.5*sin(angle);ix,iy=x+1.05*cos(angle),13+1.05*sin(angle)
                outer.append((ox,oy,hull_z(ox,oy,.08)));inner.append((ix,iy,hull_z(ix,iy,.10)))
            for j in range(8):
                k=(j+1)%8;quad(outer[j],outer[k],inner[k],inner[j],GREY,'porthole-rim',(0,0,side))
            for j in range(0,8,2):quad((x,13,hull_z(x,13,.11)),inner[j],inner[(j+1)%8],inner[(j+2)%8],BLACK,'porthole',(0,0,side))
    for z in (18,30):box(18,20,20,22,z-1,z+1,BLACK,'bollard',WHITE)
    return faces

def build_indices():
    """No overlapping voxel skin; geometry is returned by build_surfaces."""
    return {}

def build(sp):
    assert sp['W']==WIDTH and sp['H']==DEPTH
    for (x,z),shade in ((WHITE,0),(GREY,1),(DARK,2),(BLACK,3)):
        assert sp['col'][z][x]==shade
    sp['surfaces']=build_surfaces()
    return {}

def verify_intent(_=None):
    faces=build_surfaces()
    assert len(faces)<4000
    for f in faces:
        assert f['source'] in (WHITE,GREY,DARK,BLACK)
        for p in f['points']:assert -EPS<=p[0]<=128+EPS and -EPS<=p[1]<=55+EPS and -EPS<=p[2]<=48+EPS
        for axis in range(3):
            lo=min(p[axis] for p in f['points']);hi=max(p[axis] for p in f['points'])
            assert hi-lo<=8+EPS
    return {'surfaces':len(faces),'vertices':len(faces)*4,'indices':len(faces)*6,'proxy_voxels':0,'roles':dict(Counter(f['role'] for f in faces))}
