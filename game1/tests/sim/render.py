import csv, math, sys
from PIL import Image, ImageDraw
rows=[]
for r in csv.reader(open('parts.csv')):
    v=list(map(float,r[:15])); col=tuple(int(x) for x in r[15:18]); name=r[18]
    rows.append((v,col,name))
def corners(v):
    px,py,pz,sx,sy,sz=v[:6]; R=v[6:9];U=v[9:12];L=v[12:15]
    # local Z axis = -LookVector
    out=[]
    for a in (-1,1):
        for b in (-1,1):
            for c in (-1,1):
                x=px+R[0]*a*sx/2+U[0]*b*sy/2-L[0]*c*sz/2
                y=py+R[1]*a*sx/2+U[1]*b*sy/2-L[1]*c*sz/2
                z=pz+R[2]*a*sx/2+U[2]*b*sy/2-L[2]*c*sz/2
                out.append((x,y,z))
    return out
FACES=[(0,1,3,2),(4,5,7,6),(0,1,5,4),(2,3,7,6),(0,2,6,4),(1,3,7,5)]
def hull(pts):
    pts=sorted(set(pts))
    if len(pts)<3: return pts
    def cr(o,a,b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lo=[];up=[]
    for p in pts:
        while len(lo)>=2 and cr(lo[-2],lo[-1],p)<=0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up)>=2 and cr(up[-2],up[-1],p)<=0: up.pop()
        up.append(p)
    return lo[:-1]+up[:-1]
def topdown(fn,x0,x1,z0,z1,scale):
    W=int((x1-x0)*scale);H=int((z1-z0)*scale)
    im=Image.new('RGB',(W,H),(10,8,16));d=ImageDraw.Draw(im)
    items=[]
    for v,col,name in rows:
        cs=corners(v)
        items.append((max(c[1] for c in cs),cs,col,name))
    items.sort(key=lambda t:t[0])
    for top,cs,col,name in items:
        pts=hull([((c[0]-x0)*scale,(z1-c[2])*scale) for c in cs])
        if len(pts)>=3: d.polygon(pts,fill=col)
    im.save(fn)
def persp(fn,cam,target,W=1280,H=720,fov=70):
    import numpy as np
    cam=np.array(cam,float);t=np.array(target,float)
    f=t-cam;f/=np.linalg.norm(f);r=np.cross(f,[0,1,0]);r/=np.linalg.norm(r);u=np.cross(r,f)
    foc=(W/2)/math.tan(math.radians(fov/2))
    im=Image.new('RGB',(W,H),(22,16,40));d=ImageDraw.Draw(im)
    polys=[]
    light=np.array([0.3,0.8,-0.5]);light/=np.linalg.norm(light)
    for v,col,name in rows:
        if name in('GraveyardGround',): pass
        cs=[np.array(c) for c in corners(v)]
        for fc in FACES:
            q=[cs[i] for i in fc]
            n=np.cross(q[1]-q[0],q[2]-q[0]); nn=np.linalg.norm(n)
            if nn<1e-9: continue
            n/=nn
            ctr=sum(q)/4
            if np.dot(n,ctr-cam)>0: n=-n
            rel=[p-cam for p in q]
            zs=[np.dot(p,f) for p in rel]
            if min(zs)<0.5: continue
            pts=[(W/2+foc*np.dot(p,r)/z, H/2-foc*np.dot(p,u)/z) for p,z in zip(rel,zs)]
            if all(x<-200 or x>W+200 for x,_ in pts): continue
            dist=np.linalg.norm(ctr-cam)
            shade=0.55+0.45*max(0,np.dot(n,light))
            neon = name in ('Rim','Frame','Lantern','Flame','RingFlame','MoonBall','Window','Eye','Smile','Arrow','KillStrip','SpinnerBar','Slit')
            if neon: shade=1.0
            fogk=min(1,dist/700)
            c=tuple(int(col[i]*shade*(1-fogk)+ (40,28,70)[i]*fogk) for i in range(3))
            polys.append((dist,pts,c))
    polys.sort(key=lambda t:-t[0])
    for _,pts,c in polys: d.polygon(pts,fill=c)
    im.save(fn)
topdown('top_lobby.png',-105,60,-75,80,5)
topdown('top_full.png',-110,340,-400,345,1.4)
persp('view_spawn.png',(0,23,-20),(0,17,40))
persp('view_south.png',(0,23,8),(0,17,-60))
persp('view_east.png',(-5,23,0),(60,17,0))
