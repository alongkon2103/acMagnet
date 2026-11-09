"""Hand-built MAGNET LAB environment. Run in Blender, then export_game().
Source units are Roblox studs; export geometry is baked to metres (0.28 m/stud).
Only the named generated collection is replaced when rebuilding.
"""
import bpy, math, random, json, os
from mathutils import Vector
from collections import defaultdict

OUT = r'C:/Users/IssaraNV/Documents/Roblox/ACMagnet/assets/maps/copper-conservatory'
NAME = 'MAGNET_Conservatory'
M = {}
RNG = random.Random(2038)
COL = None
ZONE = 'Terrace'

def lin(c):
    return c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4

def material(name, hexcode, metal=0, rough=.6, alpha=1, emission=0):
    srgb = [int(hexcode[i:i+2],16)/255 for i in (0,2,4)]
    rgba = tuple(lin(c) for c in srgb)+(alpha,)
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = rgba
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Alpha'].default_value = alpha
    if emission:
        bsdf.inputs['Emission Color'].default_value = rgba
        bsdf.inputs['Emission Strength'].default_value = emission
    mat.diffuse_color = rgba
    mat['srgb'] = srgb; mat['alpha'] = alpha; mat['metallic'] = metal; mat['roughness'] = rough
    M[name] = mat
    return mat

def attach(obj, name, mat, smooth=False, bevel=0):
    obj.name=name; obj['zone']=ZONE
    for collection in list(obj.users_collection): collection.objects.unlink(obj)
    COL.objects.link(obj)
    obj.data.materials.append(M[mat])
    if obj.type=='MESH':
        for p in obj.data.polygons: p.use_smooth=smooth
    if bevel:
        mod=obj.modifiers.new('Soft machined edges','BEVEL');mod.width=bevel;mod.segments=3
        mod=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    return obj

def mesh(name, verts, faces, mat, smooth=False, bevel=0):
    data=bpy.data.meshes.new(name+'_mesh');data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj)
    return attach(obj,name,mat,smooth,bevel)

def box(name, pos, size, mat, bevel=.12, rot=0):
    x,y,z=[s/2 for s in size]
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    obj=mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,bevel=bevel)
    obj.location=pos;obj.rotation_euler.z=rot;return obj

def cylinder(name,pos,radius,depth,mat,n=64,bevel=.06):
    verts=[(radius*math.cos(i*2*math.pi/n),radius*math.sin(i*2*math.pi/n),z) for z in (-depth/2,depth/2) for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj=mesh(name,verts,faces,mat,bevel=bevel);obj.location=pos
    for p in obj.data.polygons[2:]:p.use_smooth=True
    return obj

def band(name,r0,r1,z0,z1,a0,a1,mat,n=None):
    n=n or max(8,int(abs(a1-a0)/360*128));a0,a1=map(math.radians,(a0,a1))
    verts=[]
    for z,r in [(z0,r0),(z0,r1),(z1,r0),(z1,r1)]:
        verts.extend((r*math.cos(a0+(a1-a0)*i/n),r*math.sin(a0+(a1-a0)*i/n),z) for i in range(n+1))
    k=n+1;faces=[]
    for i in range(n):
        faces.extend([(i,i+1,k+i+1,k+i),(2*k+i,3*k+i,3*k+i+1,2*k+i+1),(i,2*k+i,2*k+i+1,i+1),(k+i,k+i+1,3*k+i+1,3*k+i)])
    faces.extend([(0,k,3*k,2*k),(n,2*k+n,3*k+n,k+n)])
    obj=mesh(name,verts,faces,mat)
    for i,p in enumerate(obj.data.polygons):p.use_smooth=(i%4>=2 and i<4*n)
    return obj

def tube(name, points, radius, mat, cyclic=False, resolution=2):
    data=bpy.data.curves.new(name+'_curve','CURVE');data.dimensions='3D';data.resolution_u=1
    data.bevel_depth=radius;data.bevel_resolution=resolution;data.use_fill_caps=True
    spline=data.splines.new('POLY');spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points):p.co=(*co,1)
    spline.use_cyclic_u=cyclic
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj);return attach(obj,name,mat)

def ring(name, radius, z, thickness, mat, center=(0,0), start=0, end=360, n=128):
    points=[(center[0]+radius*math.cos(math.radians(start+(end-start)*i/n)),center[1]+radius*math.sin(math.radians(start+(end-start)*i/n)),z)for i in range(n+1)]
    return tube(name,points,thickness,mat,cyclic=end-start==360)

def ellipsoid(name,pos,size,mat,rot=(0,0,0),segments=16,rings=8):
    verts=[]
    for j in range(rings+1):
        phi=math.pi*j/rings
        for i in range(segments):
            a=2*math.pi*i/segments
            verts.append((size[0]*math.sin(phi)*math.cos(a),size[1]*math.sin(phi)*math.sin(a),size[2]*math.cos(phi)))
    faces=[]
    for j in range(rings):
        for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
    obj=mesh(name,verts,faces,mat,True);obj.location=pos;obj.rotation_euler=rot;return obj

def text(name,content,pos,size,mat,rot=(math.pi/2,0,0)):
    data=bpy.data.curves.new(name+'_text','FONT');data.body=content;data.size=size;data.align_x='CENTER';data.align_y='CENTER';data.extrude=.025;data.bevel_depth=.008;data.bevel_resolution=1
    font=r'C:/Windows/Fonts/bahnschrift.ttf'
    if os.path.exists(font):data.font=bpy.data.fonts.load(font,check_existing=True)
    obj=bpy.data.objects.new(name,data);COL.objects.link(obj);obj.location=pos;obj.rotation_euler=rot;return attach(obj,name,mat)

def polar(r,a,z=0):a=math.radians(a);return (r*math.cos(a),r*math.sin(a),z)

def setup():
    global COL,RNG
    RNG=random.Random(2038)
    old=bpy.data.collections.get(NAME)
    if old:
        for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(old)
    COL=bpy.data.collections.new(NAME);bpy.context.scene.collection.children.link(COL)
    for c in bpy.context.scene.collection.children:
        if c!=COL:c.hide_render=True;c.hide_viewport=True
    for name,color,metal,rough,alpha,emit in [
        ('Ivory','E8DEBF',0,.72,1,0),('Porcelain','F2ECD9',.04,.36,1,0),
        ('SageFloor','A6B6A0',0,.82,1,0),('FloorFleck','C0CBB5',0,.8,1,0),
        ('SageEnamel','577B68',.15,.38,1,0),('DeepGreen','234D40',.1,.48,1,0),
        ('Copper','B47C50',.65,.38,1,0),('Brass','D4AF6A',.65,.35,1,0),
        ('Walnut','8C6346',0,.65,1,0),('Soil','525949',0,1,1,0),
        ('LeafDark','315F42',0,.85,1,0),('LeafLight','60845A',0,.8,1,0),
        ('Water','4F8B83',.35,.22,1,0),('Glass','B0CBBE',.12,.2,.24,0),
        ('Lamp','FFE6B1',0,.4,1,1.2),('Charcoal','3D4940',.15,.6,1,0),
        ('Clay','BC8870',0,.9,1,0),('Ground','8E9F85',0,1,1,0)]:
        material(name,color,metal,rough,alpha,emit)
    bpy.context.scene.unit_settings.scale_length=1
    os.makedirs(OUT,exist_ok=True)
    print('Prepared separate conservatory collection; original default scene is hidden.')

def foundation():
    global ZONE
    ZONE='Landscape'
    cylinder('Soft island foundation',(0,0,-4.0),105,2,'Ground',128,.7)
    ZONE='Terrace'
    cylinder('Undercut sage plinth',(0,0,-2.25),59.5,2.3,'DeepGreen',128,.3)
    cylinder('Floating porcelain lip',(0,0,-.9),60.6,.8,'Porcelain',128,.22)
    band('Ivory promenade',45.1,60.2,-.55,-.16,0,360,'Ivory')
    band('Warm timber walking band',51.4,57.3,-.14,-.02,0,360,'Walnut')
    for r in (45.45,50.9,57.6,60.15):ring('Fine copper terrace seam',r,.015,.055,'Copper')
    for i in range(80):
        a=i*4.5
        p0=polar(51.6,a,.025);p1=polar(57.1,a,.025)
        tube('Timber expansion joint',[p0,p1],.025,'Ivory',resolution=1)
    band('Continuous rounded playing rim',45.0,46.0,-.05,.48,0,360,'Porcelain')
    ring('Copper inner rim',45.18,.48,.095,'Copper')
    ring('Warm recessed perimeter light',45.78,.25,.065,'Lamp')
    ZONE='FloorTile'
    cylinder('FloorTile',(0,0,-.15),45,.7,'SageFloor',128,.02)
    ZONE='FieldDetail'
    # Sparse near-tone terrazzo chips are actual low-contrast geometry; the play field stays quiet.
    for i in range(210):
        r=43.5*math.sqrt(RNG.random());a=RNG.random()*math.tau
        s=RNG.uniform(.05,.14)
        obj=box('Subtle stone fleck',(r*math.cos(a),r*math.sin(a),.204),(s,s*RNG.uniform(1,2.8),.008),'FloorFleck',0,rot=RNG.random()*math.tau)
    ring('Fine edge field inlay',43.8,.208,.025,'DeepGreen')
    # Entry bridge: broad soft steps and a pair of low rails rather than an obstructing gate.
    ZONE='Entry'
    for i in range(4):box('Rounded entry step',(0,-64.0-i*3.1,-.3-i*.23),(25-i*1.4,4,.6),'Porcelain',.25)
    for sign in (-1,1):
        tube('Entrance copper handrail',[(sign*12.1,-58,2),(sign*12.1,-64,2),(sign*10.4,-74,.7)],.15,'Copper',resolution=3)
    print('Built quiet circular field, layered terrace and entry bridge.')

def arch(name,center,width,height,depth,mat,rotation=0):
    # A continuous architectural arch with a semicircular crown and rounded tube section.
    cx,cy,cz=center;r=width/2
    local=[(-r,0,0),(-r,0,height-r)]
    local += [(r*math.cos(math.pi-i*math.pi/32),0,height-r+r*math.sin(math.pi-i*math.pi/32))for i in range(33)]
    local += [(r,0,0)]
    points=[(cx+x*math.cos(rotation)-y*math.sin(rotation),cy+x*math.sin(rotation)+y*math.cos(rotation),cz+z)for x,y,z in local]
    return tube(name,points,depth/2,mat,resolution=3)

def architecture():
    global ZONE
    ZONE='Observatory'
    # Northern gallery, deliberately higher than the side gardens and workstations.
    band('Gallery landing',60.7,79,-.5,.1,32,148,'Porcelain')
    for i,a in enumerate([38,55,72,90,108,125,142]):
        x,y,z=polar(73,a,.1)
        arch('Gallery porcelain arch',(x,y,z),12.7,17.6,1.65,'Porcelain',math.radians(a-90))
        # A thin copper line follows each arch's profile, offset towards the arena.
        nx,ny=polar(-.85,a)[:2]
        arch('Inlaid copper arch',(x+nx,y+ny,.1),12.65,17.55,.16,'Copper',math.radians(a-90))
    band('Gallery crown fascia',71.8,74.1,17.7,18.5,32,148,'SageEnamel')
    ring('Gallery brass cornice',73.1,18.55,.13,'Brass',start=32,end=148,n=88)
    # Clear curved canopy, divided into small panes between copper ribs.
    for i in range(14):
        a0=34+i*8.0;a1=a0+7.4
        canopy=band('Curved glazed gallery roof',63.6,77,18.25,18.35,a0,a1,'Glass',n=8)
    for a in range(34,149,8):tube('Curved canopy roof rib',[polar(r,a,18.5+.45*math.sin((r-63)/14*math.pi))for r in [63+i*.5 for i in range(29)]],.11,'Copper')
    # Horseshoe sculpture is the visual anchor; its open top reads as a magnet from every useful view.
    cylinder('Magnet sculpture pedestal',(0,65,1.0),11.2,1.8,'SageEnamel',64,.3)
    cylinder('Pedestal porcelain cap',(0,65,2.0),11.5,.35,'Porcelain',64,.12)
    points=[(-7.8,65,18),(-7.8,65,10.4)]
    points += [(7.8*math.cos(math.pi+i*math.pi/40),65,10.4+7.8*math.sin(math.pi+i*math.pi/40))for i in range(41)]
    points += [(7.8,65,18)]
    tube('Giant enameled horseshoe magnet',points,2.1,'SageEnamel',resolution=4)
    # Flat tip collars and cream pole caps give the U shape a precise, crafted finish.
    for x in (-7.8,7.8):
        cylinder('Copper pole collar',(x,65,16.8),2.16,1.35,'Copper',48,.12)
        cylinder('Porcelain pole shoe',(x,65,18.25),2.2,1.0,'Porcelain',48,.14)
        ring('Pole face etching',1.45,18.76,.055,'Brass',center=(x,65),n=48)
    box('Workshop identity plaque',(0,71.3,20.0),(25,1,4.7),'Porcelain',.65)
    text('Magnet Lab lettering','MAGNET LAB',(0,70.73,20.25),2.15,'DeepGreen')
    for sign in (-1,1):
        # Sculptural instrument coils flank the hero, with warm ceramic sockets.
        cylinder('Coil display socket',(sign*20,62,1.0),3.0,1.8,'Porcelain',48,.22)
        tube('Coil core',[(sign*20,62,1.4),(sign*20,62,8)],.9,'Charcoal')
        coil=[]
        for i in range(145):
            t=i/144;angle=t*math.tau*7
            coil.append((sign*20+1.5*math.cos(angle),62+1.5*math.sin(angle),2.2+t*5.2))
        tube('Exposed copper instrument winding',coil,.18,'Copper',resolution=2)
        ellipsoid('Coil porcelain terminal',(sign*20,62,8),(1.0,1.0,.6),'Porcelain')
    print('Built curved gallery, glazed canopy and signature horseshoe observatory.')

def leaf(name,origin,length,width,heading,lift,mat):
    # Curved closed leaves, shaped along a central rib rather than sphere clumps.
    forward=Vector((math.cos(heading),math.sin(heading),0));side=Vector((-forward.y,forward.x,0))
    verts=[];steps=8
    for shell in (0,1):
        for j in range(steps+1):
            t=j/steps;w=width*(math.sin(math.pi*t)**.8+.008)
            center=Vector(origin)+forward*(length*t)+Vector((0,0,lift*math.sin(t*math.pi*.8)))
            for across in (-1,0,1):
                p=center+side*(w*across)+Vector((0,0,(-.18*abs(across)*math.sin(math.pi*t))-(.035 if shell else 0)))
                verts.append(tuple(p))
    k=(steps+1)*3;faces=[]
    for j in range(steps):
        for a in range(2):
            i=j*3+a;faces.append((i,i+1,i+4,i+3));faces.append((k+i+3,k+i+4,k+i+1,k+i))
        for a in (0,2):i=j*3+a;faces.append((i,i+3,k+i+3,k+i))
    faces.extend([(0,k,k+1,1),(1,k+1,k+2,2),(steps*3,steps*3+1,k+steps*3+1,k+steps*3),(steps*3+1,steps*3+2,k+steps*3+2,k+steps*3+1)])
    return mesh(name,verts,faces,mat,True)

def plant(pos,height=6,spread=3.4,seed=0):
    rng=random.Random(seed);x,y,z=pos
    for j in range(5):
        a=rng.random()*math.tau;h=height*rng.uniform(.55,1)
        end=(x+math.cos(a)*spread*.45,y+math.sin(a)*spread*.45,z+h)
        tube('Graceful botanical stem',[(x,y,z),(x+math.cos(a)*.25,y+math.sin(a)*.25,z+h*.55),end],.065,'LeafDark',resolution=1)
        for k in range(3):
            heading=a+k*2.2+rng.uniform(-.25,.25)
            leaf('Broad folded botanical leaf',(end[0],end[1],end[2]-k*.7),spread*rng.uniform(.8,1.2),spread*.32,heading,rng.uniform(.45,1.2),'LeafLight'if(j+k)%3==0 else'LeafDark')

def planter(pos,r=3,height=2.6,seed=0,clay=False):
    x,y,z=pos
    cylinder('Rounded botanical pot',(x,y,z+height/2),r,height,'Clay'if clay else'Porcelain',40,.28)
    ring('Planter turned rim',r-.12,z+height,.18,'Copper'if clay else'Ivory',center=(x,y),n=48)
    cylinder('Recessed planter soil',(x,y,z+height-.08),r-.35,.1,'Soil',40,0)
    plant((x,y,z+height),height*1.8,r*.9,seed)

def garden():
    global ZONE
    ZONE='BotanicalCourt'
    # Offset water court and overlapping curved seating make this side distinct from the workshop.
    cylinder('Garden courtyard dais',(-64,3,-.2),17,.8,'Porcelain',96,.3)
    cylinder('Recessed water basin',(-65,4,.35),11.1,.6,'DeepGreen',80,.16)
    cylinder('Still reflective water',(-65,4,.68),10.6,.07,'Water',80,.02)
    ring('Basin brass rim',11.0,.7,.12,'Copper',center=(-65,4),n=96)
    for i in range(7):
        a=RNG.random()*math.tau;r=RNG.uniform(2,8)
        cylinder('Botanical lily pad',(-65+r*math.cos(a),4+r*math.sin(a),.75),RNG.uniform(.5,1.0),.055,'LeafLight',24,.02)
    # Curved, backed wood benches follow two different short arcs.
    for center,angle in [((-62,-16),(-20,125)),((-76,22),(175,285))]:
        for j in range(5):
            obj=band('Curved walnut bench slat',8+j*.28,8.19+j*.28,1.25,1.57,*angle,'Walnut',n=40);obj.location.x=center[0];obj.location.y=center[1]
        for a in [angle[0]+10,angle[1]-10]:
            p=polar(8.8,a,.65);box('Bench porcelain pedestal',(center[0]+p[0],center[1]+p[1],.65),(1.6,1.6,1.3),'Porcelain',.2)
    for i,(x,y,r,h)in enumerate([(-54,24,3.8,3.1),(-63,30,3.1,2.7),(-77,-12,3.2,2.9),(-49,-17,2.8,2.4),(-82,8,2.7,2.8)]):
        planter((x,y,0),r,h,500+i,clay=i%3==0)
    # A pair of tall, gently curved lamps place warm pools of light in the garden.
    for x,y in [(-52,12),(-74,-22)]:
        cylinder('Lamp stone foot',(x,y,.3),1.3,.6,'Porcelain',32,.1)
        tube('Arched garden lamp',[(x,y,.5),(x,y,8),(x+.2,y,9.6),(x+1.2,y,10.2),(x+2.4,y,10)],.12,'Copper',resolution=3)
        ellipsoid('Garden opal lamp',(x+2.4,y,9.6),(.8,.8,.95),'Lamp',segments=24,rings=12)
    print('Built asymmetrical water garden, curved seating and folded-leaf planting.')

def workshop():
    global ZONE
    ZONE='Workshop'
    cylinder('Workshop porcelain terrace',(65,13,-.3),18,.7,'Porcelain',96,.25)
    for x,y in [(57,20),(69,18),(68,3)]:
        box('Soft enamel workbench',(x,y,1.65),(8.0,4.2,3.1),'SageEnamel',.45)
        box('Oiled wooden worktop',(x,y,3.45),(8.5,4.7,.5),'Walnut',.3)
        for dx in (-2.6,0,2.6):
            box('Workshop cabinet front',(x+dx,y-2.15,1.8),(2.4,.12,2.0),'Ivory',.12)
            tube('Copper cabinet pull',[(x+dx-.45,y-2.3,2.35),(x+dx+.45,y-2.3,2.35)],.07,'Copper',resolution=1)
        cylinder('Spool ceramic core',(x-1.5,y,4.15),.65,1.0,'Porcelain',32,.08)
        for j in range(5):ring('Copper wire spool',.78,3.85+j*.15,.075,'Copper',center=(x-1.5,y),n=32)
        box('Instrument housing',(x+1.5,y,4.15),(2,1.4,1.1),'Porcelain',.25)
        # A small, deliberate brass instrument dial.
        dial=cylinder('Bench meter dial',(x+1.5,y-.76,4.3),.42,.08,'Brass',32,.03);dial.rotation_euler.x=math.pi/2
    for x,y in [(59,-1),(74,26)]:
        cylinder('Padded workshop stool',(x,y,2.1),1.55,.55,'Clay',40,.18)
        cylinder('Stool stem',(x,y,1.0),.25,1.7,'Copper',24,.04)
        cylinder('Stool foot',(x,y,.2),1.3,.25,'DeepGreen',32,.08)
    # Curved equipment canopy, with no obstruction over the playing area.
    for x in (53,77):arch('Workshop shade support',(x,17,.1),18,12,0.65,'Copper',math.pi/2)
    for j in range(13):
        y=8+j*1.5
        tube('Workshop linen shade batten',[(52.6,y,10.7+.7*math.sin(j/12*math.pi)),(77.4,y,10.7+.7*math.sin(j/12*math.pi))],.16,'Ivory',resolution=2)
    planter((79,10,0),3.5,2.7,700)
    planter((55,34,0),3.0,2.4,701,True)
    # Thick power cables route outwards, never through the walkable game circle.
    tube('Instrument power cable',[(56,18,.3),(54,13,.3),(56,7,.3),(61,4,.3)],.14,'DeepGreen',resolution=2)
    print('Built crafted coil workbenches, stools and a light curved shade structure.')

def surroundings():
    global ZONE
    ZONE='Landscape'
    # Soft terraced landforms, sparsely planted. No repeated ring of low-poly towers.
    for i,(x,y,scale)in enumerate([(-72,51,(17,12,2.4)),(64,54,(16,13,2.2)),(-37,87,(18,12,1.8)),(39,91,(20,12,2.0)),(-89,-37,(12,14,1.5)),(82,-33,(14,12,1.8))]):
        ellipsoid('Sculpted garden bank',(x,y,-1.8),scale,'Ground',segments=32,rings=12)
        for j in range(3):
            dx=RNG.uniform(-5,5);dy=RNG.uniform(-4,4)
            plant((x+dx,y+dy,-.3),RNG.uniform(4.5,7.5),RNG.uniform(2.5,3.6),900+i*7+j)
    # Small ceramic path lanterns guide the entry, with a restrained rhythm and staggered planting.
    ZONE='Entry'
    for i,(x,y)in enumerate([(-18,-59),(18,-61),(-17,-73),(17,-75)]):
        cylinder('Path lantern base',(x,y,.2),1.1,.4,'DeepGreen',32,.08)
        cylinder('Path lantern body',(x,y,1.25),.7,1.8,'Porcelain',32,.14)
        cylinder('Path lantern diffuser',(x,y,2.13),.57,.25,'Lamp',32,.06)
        cylinder('Path lantern cap',(x,y,2.38),.86,.22,'Copper',32,.08)
    for i,(x,y)in enumerate([(-31,-57),(35,-58),(-24,-79),(26,-78)]):planter((x,y,-.2),2.9,2.3,1100+i,clay=i%2==0)
    print('Built layered landscape and welcoming lantern approach.')

def finishing_gardens():
    global ZONE
    ZONE='GalleryDetail'
    band('Gallery plinth wall',75.0,76.1,.1,2.8,32,148,'SageEnamel')
    band('Turned gallery wall coping',74.8,76.3,2.8,3.1,32,148,'Porcelain')
    for a0 in range(34,147,14):
        band('Curved conservatory window',75.6,75.75,3.15,17.3,a0,a0+13.4,'Glass',n=12)
        tube('Window bronze mullion',[polar(75.5,a0,3),polar(75.5,a0,17.7)],.075,'Copper')
    ZONE='PlantedBorders'
    for j,(r0,r1,a0,a1)in enumerate([(80,92,55,126),(79,91,170,205),(85,96,-5,30)]):
        band('Curved raised garden bed',r0,r1,-.4,1.1,a0,a1,'Ivory')
        band('Dark recessed growing medium',r0+.35,r1-.35,1.1,1.16,a0+.5,a1-.5,'Soil')
        ring('Garden bed copper edge',r0+.12,1.2,.07,'Copper',start=a0,end=a1,n=64)
        for i in range(9 if j==0 else 5):
            a=a0+(a1-a0)*(i+.5)/(9 if j==0 else 5);r=RNG.uniform(r0+2,r1-2)
            plant(polar(r,a,1.1),RNG.uniform(4,6.5),RNG.uniform(2.3,3.4),1400+j*17+i)
    # Tall, irregular indoor trees provide vertical mass, individual curved leaves and readable trunks.
    ZONE='ConservatoryTrees'
    for tree_index,(x,y,height)in enumerate([(-85,29,18),(83,40,20),(-32,92,23),(37,94,20)]):
        cylinder('Large rounded tree planter',(x,y,1.0),3.8,2.8,'Ivory',48,.3)
        cylinder('Tree root earth',(x,y,2.43),3.45,.08,'Soil',48,0)
        lean=1 if tree_index%2==0 else -1
        stem=tube('Curved walnut trunk',[(x,y,2.4),(x+lean*.5,y,height*.5),(x+lean*2.0,y+.6,height*.82)],.64,'Walnut',resolution=3)
        for i,p in enumerate(stem.data.splines[0].points):p.radius=1-i*.32
        for branch in range(5):
            a=branch*2.4+tree_index*.7
            start=Vector((x+lean*1.3,y+.3,height*.55+branch*.7))
            end=start+Vector((math.cos(a)*4.2,math.sin(a)*4.2,height*.16))
            twig=tube('Swept botanical branch',[tuple(start),tuple(start.lerp(end,.6)+Vector((0,0,.7))),tuple(end)],.20,'Walnut',resolution=2)
            for i,p in enumerate(twig.data.splines[0].points):p.radius=1-i*.3
            for k in range(7):
                heading=a+k*math.tau/7
                origin=end+Vector((math.cos(heading)*.45,math.sin(heading)*.45,(k%3)*.35))
                leaf('Tree canopy individual leaf',tuple(origin),RNG.uniform(3.3,5.0),RNG.uniform(.8,1.3),heading,RNG.uniform(.4,1.3),'LeafLight'if k%3==0 else'LeafDark')
    # Paths connect the destination courts instead of leaving decorative islands unconnected.
    ZONE='GardenPaths'
    band('Western garden path',62,66,-.1,.02,188,250,'Ivory')
    band('Eastern workshop path',62,66,-.1,.02,-75,-5,'Ivory')
    for x,y,rot in [(-46,-55,.4),(45,-55,-.4)]:
        for i in range(4):box('Rounded garden stepping slab',(x+i*math.sin(rot)*2.8,y-i*math.cos(rot)*2.8,.08),(3.8,2.2,.22),'Porcelain',.24,rot)
    print('Added botanical tree silhouettes, layered raised planting, curved windows and linked paths.')

def preview():
    scene=bpy.context.scene
    # Keep all preview-only objects outside the export selection.
    world=scene.world or bpy.data.worlds.new('Warm conservatory daylight');scene.world=world;world.use_nodes=True
    node=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');node.inputs['Color'].default_value=(.65,.72,.65,1);node.inputs['Strength'].default_value=.65
    for name,kind,pos,energy,size in [('Conservatory sun','SUN',(90,-100,140),2.2,.15),('Large softbox','AREA',(-50,-20,100),150000,90)]:
        data=bpy.data.lights.new(name,kind);data.energy=energy
        if kind=='SUN':data.angle=size
        else:data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(name,data);COL.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
    camera=bpy.data.objects.new('Conservatory overview',bpy.data.cameras.new('Overview lens'));COL.objects.link(camera)
    camera.location=(150,-188,178);target=Vector((0,3,2));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=220;scene.camera=camera
    scene.render.resolution_x=1500;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.filepath=OUT+'/conservatory-overview.png'
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=OUT+'/magnet-conservatory.blend')
    print('Saved editable Blender source with overview camera.')

def export_game():
    """Evaluate on temporary meshes; merge by zone/material under the20K triangle limit."""
    previous=bpy.data.collections.get('EXPORT_TEMP')
    if previous:
        for obj in list(previous.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(previous)
    deps=bpy.context.evaluated_depsgraph_get();groups=defaultdict(list)
    for obj in list(COL.objects):
        if obj.type not in {'MESH','CURVE','FONT'}:continue
        ev=obj.evaluated_get(deps);data=ev.to_mesh();verts=[tuple((obj.matrix_world@v.co)*.28)for v in data.vertices]
        faces=[tuple(p.vertices)for p in data.polygons];smooth=[p.use_smooth for p in data.polygons]
        tris=sum(len(p.vertices)-2 for p in data.polygons)
        mat=obj.data.materials[0];groups[(obj.get('zone','Details'),mat.name)].append((verts,faces,smooth,tris))
        ev.to_mesh_clear()
    collection=bpy.data.collections.new('EXPORT_TEMP');bpy.context.scene.collection.children.link(collection)
    export_objects=[];manifest=[];allverts=[]
    def flush(key,chunk,index):
        if not chunk:return
        verts=[];faces=[];smoothing=[]
        for vv,ff,ss,tt in chunk:
            offset=len(verts);verts.extend(vv);faces.extend(tuple(i+offset for i in f)for f in ff);smoothing.extend(ss)
        name=key[0]+'__'+key[1]+'__'+str(index).zfill(2)
        data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
        for p,s in zip(data.polygons,smoothing):p.use_smooth=s
        obj=bpy.data.objects.new(name,data);collection.objects.link(obj);data.materials.append(bpy.data.materials[key[1]])
        export_objects.append(obj);allverts.extend(verts)
        manifest.append({'name':name,'triangles':sum(len(f)-2 for f in faces),'material':key[1],'srgb':list(bpy.data.materials[key[1]]['srgb']),'alpha':bpy.data.materials[key[1]]['alpha'],'metallic':bpy.data.materials[key[1]]['metallic']})
    for key,items in groups.items():
        chunk=[];tri=0;index=1
        for item in items:
            if chunk and tri+item[3]>12000:flush(key,chunk,index);chunk=[];tri=0;index+=1
            assert item[3]<=20000,(key,item[3])
            chunk.append(item);tri+=item[3]
        flush(key,chunk,index)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in export_objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=export_objects[0]
    props=bpy.ops.export_scene.gltf.get_rna_type().properties
    formats=[i.identifier for i in props['export_format'].enum_items]
    # Dynamic exporter enums can return an empty RNA item list; GLB was verified by its operator error.
    fmt=next((v for v in formats if v=='GLB'),'GLB')
    bpy.ops.export_scene.gltf(filepath=OUT+'/magnet-conservatory.glb',export_format=fmt,use_selection=True,export_yup=True,export_apply=True,export_cameras=False,export_lights=False)
    bounds={'min_m':[min(v[i]for v in allverts)for i in range(3)],'max_m':[max(v[i]for v in allverts)for i in range(3)]}
    record={'source_units':'stud','metres_per_stud':.28,'meshes':manifest,'bounds':bounds,'orientation':'hero magnet at source +Y (Roblox -Z); water garden source-X; workshop source+X','floor_diameter_studs':90,'floor_top_studs':.2}
    with open(OUT+'/manifest.json','w')as file:json.dump(record,file,indent=2)
    for obj in export_objects:bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(collection)
    print(json.dumps({'meshes':len(manifest),'triangles':sum(m['triangles']for m in manifest),'max_mesh_triangles':max(m['triangles']for m in manifest),'bytes':os.path.getsize(OUT+'/magnet-conservatory.glb'),'bounds':bounds}))

if __name__=='__main__':
    setup();foundation();architecture();garden();workshop();surroundings();finishing_gardens();preview();export_game()
