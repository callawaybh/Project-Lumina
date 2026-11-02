"""Original low-poly club modules, standard embedded GLB materials/lights/OMI seats."""
from pathlib import Path
import math,struct,json,wave,random
OUT=Path(__file__).resolve().parent/'models';OUT.mkdir(exist_ok=True)
MATS={
'black':([.022,.024,.03,1],.18,.62,None), 'charcoal':([.055,.055,.068,1],.15,.7,None),
'wood':([.075,.032,.025,1],.05,.6,None), 'burgundy':([.22,.018,.04,1],0,.78,None),
'metal':([.32,.34,.38,1],.85,.26,None),'darkmetal':([.08,.085,.105,1],.75,.32,None),
'red':([.35,.008,.02,1],.1,.35,([1,.015,.04],4)), 'violet':([.15,.018,.32,1],.1,.35,([.35,.035,1],3)),
'amber':([.3,.13,.025,1],.1,.3,([1,.45,.10],3)), 'white':([.6,.65,.75,1],.1,.4,([.7,.8,1],1.8)),
'green':([.015,.09,.04,1],0,.9,None),'bottlegreen':([.018,.14,.07,1],.1,.25,None),
'bottleamber':([.24,.08,.012,1],.1,.3,None), 'glass':([.25,.28,.32,1],.4,.18,None)
}
def sub(a,b):return [x-y for x,y in zip(a,b)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def normal(a,b,c):
    n=cross(sub(b,a),sub(c,a));l=math.sqrt(sum(v*v for v in n));return [v/l for v in n]
class Model:
    def __init__(self,name):self.name=name;self.geo={};self.extra=[];self.lights=[]
    def tri(self,mat,a,b,c):
        n=normal(a,b,c);g=self.geo.setdefault(mat,[])
        for p in [a,b,c]:g.append((p,n))
    def quad(self,mat,a,b,c,d):self.tri(mat,a,b,c);self.tri(mat,a,c,d)
    def box(self,mat,c,s,rz=0,ry=0):
        x,y,z=[v/2 for v in s]
        vs=[[-x,-y,-z],[x,-y,-z],[x,y,-z],[-x,y,-z],[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z]]
        for p in vs:
            xx,yy=p[0],p[1];p[0]=xx*math.cos(rz)-yy*math.sin(rz);p[1]=xx*math.sin(rz)+yy*math.cos(rz)
            xx,zz=p[0],p[2];p[0]=xx*math.cos(ry)+zz*math.sin(ry);p[2]=-xx*math.sin(ry)+zz*math.cos(ry)
            for i in range(3):p[i]+=c[i]
        for a,b,c0,d in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)]:self.quad(mat,*[vs[v] for v in [a,b,c0,d]])
    def cyl(self,mat,c,r,h,n=20,axis='y'):
        def point(x,y,z):
            p=[x,y,z] if axis=='y' else [x,z,y]
            return [p[i]+c[i] for i in range(3)]
        for i in range(n):
            a=i*math.tau/n;b=(i+1)*math.tau/n
            p=point(r*math.cos(a),-h/2,r*math.sin(a));q=point(r*math.cos(b),-h/2,r*math.sin(b));u=point(r*math.cos(a),h/2,r*math.sin(a));v=point(r*math.cos(b),h/2,r*math.sin(b))
            if axis=='y':
                self.quad(mat,p,u,v,q);self.tri(mat,point(0,h/2,0),v,u);self.tri(mat,point(0,-h/2,0),p,q)
            else:
                self.quad(mat,p,q,v,u);self.tri(mat,point(0,h/2,0),u,v);self.tri(mat,point(0,-h/2,0),q,p)
    def seat(self,x=0,y=.5,z=0):
        self.extra.append({'name':'Seat_%d'%len(self.extra),'translation':[float(x),float(y-.5),float(z)],'extensions':{'OMI_seat':{'foot':[0.,0.,.5],'knee':[0.,.5,.5],'back':[0.,.5,0.],'angle':1.57079632679}}})
    def light(self,name,pos,color,energy=2,radius=8):
        idx=len(self.lights);self.lights.append({'name':name,'type':'point','color':color,'intensity':energy,'range':radius})
        self.extra.append({'name':name,'translation':pos,'extensions':{'KHR_lights_punctual':{'light':idx}}})
    def save(self):
        data=bytearray();views=[];accessors=[];materials=[];primitives=[];used=[]
        def accessor(values,width):
            while len(data)%4:data.append(0)
            off=len(data);flat=[v for a in values for v in a];data.extend(struct.pack('<%df'%len(flat),*flat))
            views.append({'buffer':0,'byteOffset':off,'byteLength':len(data)-off,'target':34962})
            a={'bufferView':len(views)-1,'componentType':5126,'count':len(values),'type':{3:'VEC3'}[width]}
            if width==3:a.update(min=[min(p[i] for p in values) for i in range(3)],max=[max(p[i] for p in values) for i in range(3)])
            accessors.append(a);return len(accessors)-1
        for name,geo in self.geo.items():
            color,metal,rough,emission=MATS[name]
            mat={'name':name,'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':metal,'roughnessFactor':rough}}
            if emission:
                mat.update(emissiveFactor=emission[0],extensions={'KHR_materials_emissive_strength':{'emissiveStrength':emission[1]}})
                if 'KHR_materials_emissive_strength' not in used:used.append('KHR_materials_emissive_strength')
            materials.append(mat)
            primitives.append({'attributes':{'POSITION':accessor([p for p,n in geo],3),'NORMAL':accessor([n for p,n in geo],3)},'material':len(materials)-1,'mode':4})
        nodes=[{'name':self.name,'children':list(range(1,2+len(self.extra)))},{'name':'Geometry','mesh':0}]+self.extra
        doc={'asset':{'version':'2.0','generator':'Project Lumina original procedural modules'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'meshes':[{'primitives':primitives}],'materials':materials,'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':accessors}
        if self.lights:doc['extensions']={'KHR_lights_punctual':{'lights':self.lights}};used.append('KHR_lights_punctual')
        if any('OMI_seat' in n.get('extensions',{}) for n in self.extra):used.append('OMI_seat')
        if used:doc['extensionsUsed']=used
        js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);data+=b'\0'*((-len(data))%4)
        result=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data
        (OUT/(self.name+'.glb')).write_bytes(result)
        vertices=[p for geo in self.geo.values() for p,n in geo]
        return {'file':self.name+'.glb','bounds':{'position':[min(p[i] for p in vertices) for i in range(3)],'size':[max(p[i] for p in vertices)-min(p[i] for p in vertices) for i in range(3)]},'meshes':1,'emissive_surfaces':sum(1 for k in self.geo if MATS[k][3]),'seats':sum(1 for n in self.extra if 'OMI_seat' in n.get('extensions',{})),'lights':len(self.lights),'bytes':len(result)}
MODELS={}
def save(m):MODELS[m.name]=m.save()
# Long left-wall bar, detailed panel fronts, floating-looking metal toe rail.
m=Model('bar_counter');m.box('black',[0,.5,0],[1.15,1,16]);m.box('darkmetal',[0,1.08,0],[1.45,.16,16.2]);m.box('amber',[.731,1.035,0],[.025,.035,15.9]);m.box('metal',[.72,.22,0],[.055,.055,15.8])
for z in [-6,-4,-2,0,2,4,6]:m.box('wood',[.582,.55,z],[.03,.72,1.88]);m.box('metal',[.602,.55,z+.94],[.02,.72,.018])
save(m)
m=Model('backbar');m.box('black',[0,1.65,0],[.18,3.3,14.4]);m.box('darkmetal',[.32,.52,0],[.7,.08,14.4])
for y in [1.1,1.9,2.7]:
    m.box('darkmetal',[.31,y,0],[.72,.07,14.4]);m.box('amber',[.66,y-.045,0],[.025,.025,14.2])
    for i,z in enumerate([v*.72 for v in range(-9,10)]):
        m.cyl('bottlegreen' if i%2 else 'bottleamber',[.28,y+.17,z],.055,.27,10);m.cyl('metal',[.28,y+.34,z],.023,.07,10)
for z in [-7.2,-2.4,2.4,7.2]:m.box('metal',[.05,1.65,z],[.04,3.3,.035])
save(m)
m=Model('stool');m.cyl('darkmetal',[0,.045,0],.3,.09);m.cyl('metal',[0,.39,0],.055,.65);m.cyl('metal',[0,.28,0],.19,.035);m.cyl('black',[0,.74,0],.31,.13);m.cyl('burgundy',[0,.82,0],.32,.07);m.box('darkmetal',[0,1,-.24],[.48,.3,.07]);m.seat(y=.855,z=-.02);save(m)
# Three-cushion sofa; one clearly centered native interaction marker per object.
m=Model('sofa');m.box('black',[0,.17,0],[2.8,.22,.9]);m.box('burgundy',[0,.75,-.39],[2.8,.95,.23]);m.box('burgundy',[-1.36,.55,0],[.18,.55,1]);m.box('burgundy',[1.36,.55,0],[.18,.55,1])
for x in [-.87,0,.87]:m.box('burgundy',[x,.43,.03],[.82,.22,.81]);m.box('burgundy',[x,.86,-.25],[.82,.57,.14])
for x in [-1.12,1.12]:
    for z in [-.29,.29]:m.cyl('metal',[x,.07,z],.045,.14,10)
m.seat(y=.54,z=-.10);save(m)
m=Model('armchair');m.box('black',[0,.15,0],[.95,.25,.9]);m.box('burgundy',[0,.77,-.37],[1,.97,.24]);m.box('burgundy',[0,.43,0],[.8,.24,.78]);m.box('burgundy',[-.47,.6,0],[.16,.6,.9]);m.box('burgundy',[.47,.6,0],[.16,.6,.9]);m.seat(y=.55,z=-.1);save(m)
m=Model('table');m.cyl('darkmetal',[0,.035,0],.34,.07);m.cyl('metal',[0,.24,0],.045,.4);m.cyl('black',[0,.48,0],.62,.08,32);m.cyl('metal',[0,.445,0],.625,.016,32);save(m)
m=Model('table_details')
for x,z in [(-.18,.06),(.12,-.12)]:m.cyl('glass',[x,.085,z],.045,.17,12);m.cyl('bottleamber',[x,.042,z],.037,.07,12)
m.cyl('darkmetal',[0,.025,0],.075,.05);m.cyl('amber',[0,.065,0],.035,.05);save(m)
# Console, decks, faders, and a low tilted-looking control fascia.
m=Model('dj_console');m.box('black',[0,.45,0],[6,.9,1.15]);m.box('darkmetal',[0,.98,0],[6.2,.16,1.35]);m.box('red',[0,.64,.585],[5.7,.035,.025]);m.box('metal',[0,.1,.58],[5.8,.035,.025])
for x in [-1.9,1.9]:
    m.box('black',[x,1.09,0],[1.5,.08,1]);m.cyl('metal',[x,1.15,0],.36,.04,32);m.cyl('black',[x,1.177,0],.3,.018,32);m.cyl('red',[x,1.189,0],.04,.01)
    for k in range(5):m.box('violet',[x-.5+k*.2,1.14,.4],[.09,.025,.07])
m.box('black',[0,1.09,0],[1.25,.1,1])
for x in [-.4,-.2,0,.2,.4]:
    m.box('metal',[x,1.15,.1],[.015,.015,.45]);m.box('white',[x,1.165,.1],[.075,.025,.055]);m.cyl('darkmetal',[x,1.18,-.35],.045,.06,12)
m.box('metal',[0,1.35,-.34],[.95,.05,.45]);m.box('black',[0,1.62,-.55],[1.1,.55,.04]);m.box('violet',[0,1.62,-.523],[.96,.39,.01]);save(m)
m=Model('speaker');m.box('black',[0,1.35,0],[1,2.7,.85]);m.box('darkmetal',[0,1.35,.433],[.9,2.57,.025])
for y,r in [(.48,.34),(1.3,.34),(2.12,.2)]:
    m.cyl('metal',[0,y,.457],r,.025,32,'z');m.cyl('black',[0,y,.477],r*.88,.025,32,'z');m.cyl('darkmetal',[0,y,.494],r*.36,.02,24,'z')
m.box('red',[0,2.54,.452],[.3,.035,.015]);save(m)
m=Model('dj_backdrop');m.box('black',[0,2.65,0],[11.8,5.3,.16])
for x in [-5.7,5.7]:m.box('metal',[x,2.65,.1],[.04,5.1,.04])
save(m)
m=Model('crescent');n=64;outer=[];inner=[]
R=1.25;r=1.06;d=.45;xi=(R*R-r*r+d*d)/(2*d);ao=math.acos(xi/R);ai=math.acos((xi-d)/r)
for i in range(n+1):
    t=i/n;theta=ao+(math.tau-2*ao)*t;phi=ai+(math.tau-2*ai)*t
    outer.append([R*math.cos(theta),R*math.sin(theta)]);inner.append([d+r*math.cos(phi),r*math.sin(phi)])
for i in range(n):
    a,b=outer[i],outer[i+1];c,e=inner[i+1],inner[i]
    m.quad('red',[a[0],a[1],.08],[b[0],b[1],.08],[c[0],c[1],.08],[e[0],e[1],.08])
    m.quad('red',[a[0],a[1],-.08],[e[0],e[1],-.08],[c[0],c[1],-.08],[b[0],b[1],-.08])
    m.quad('red',[a[0],a[1],-.08],[b[0],b[1],-.08],[b[0],b[1],.08],[a[0],a[1],.08])
    m.quad('red',[e[0],e[1],.08],[c[0],c[1],.08],[c[0],c[1],-.08],[e[0],e[1],-.08])
save(m)
m=Model('stage_lightbars')
for x,h,mat in [(-4.4,2.8,'red'),(-3.1,3.5,'violet'),(-1.8,2.3,'red'),(1.8,2.3,'violet'),(3.1,3.5,'red'),(4.4,2.8,'violet')]:
    m.box('darkmetal',[x,h/2,0],[.17,h,.12]);m.box(mat,[x,h/2,.071],[.065,h-.16,.025])
save(m)
# Geometric line lettering; original mesh text instead of a raster sign.
FONT={
'L':[[(0,1),(0,0),(.6,0)]], 'U':[[(0,1),(0,.15),(.15,0),(.45,0),(.6,.15),(.6,1)]],
'M':[[(0,0),(0,1),(.3,.5),(.6,1),(.6,0)]], 'I':[[(.3,0),(.3,1)],[(.08,1),(.52,1)],[(.08,0),(.52,0)]],
'N':[[(0,0),(0,1),(.6,0),(.6,1)]], 'A':[[(0,0),(.3,1),(.6,0)],[(.14,.4),(.46,.4)]],
'F':[[(0,0),(0,1),(.6,1)],[(0,.5),(.45,.5)]], 'T':[[(0,1),(.6,1)],[(.3,1),(.3,0)]],
'E':[[(.6,0),(0,0),(0,1),(.6,1)],[(0,.5),(.45,.5)]], 'R':[[(0,0),(0,1),(.45,1),(.6,.85),(.6,.65),(.45,.5),(0,.5)],[(.3,.5),(.6,0)]],
'D':[[(0,0),(0,1),(.4,1),(.6,.8),(.6,.2),(.4,0),(0,0)]], 'K':[[(0,0),(0,1)],[(.6,1),(0,.45),(.6,0)]],
'X':[[(0,0),(.6,1)],[(0,1),(.6,0)]]}
def text(m,word,y,height,mat):
    width=len(word)*.82*height;start=-width/2
    for j,ch in enumerate(word):
        for path in FONT.get(ch,[]):
            for (x1,y1),(x2,y2) in zip(path,path[1:]):
                dx=(x2-x1)*height;dy=(y2-y1)*height
                m.box(mat,[start+(j*.82+(x1+x2)/2)*height,y+(y1+y2)/2*height,.08],[math.hypot(dx,dy)+.02,height*.045,.035],rz=math.atan2(dy,dx))
m=Model('club_sign');m.box('black',[0,.62,0],[6,1.8,.12]);text(m,'LUMINA',.35,.85,'white');text(m,'AFTER DARK',-.12,.28,'red');save(m)
m=Model('exit_sign');m.box('black',[0,.2,0],[1.35,.55,.1]);text(m,'EXIT',.035,.34,'white');save(m)
m=Model('entry_trim')
for x in [-2.08,2.08]:m.box('darkmetal',[x,1.75,0],[.16,3.5,.14]);m.box('red',[x,1.75,.08],[.035,3.35,.025])
m.box('darkmetal',[0,3.57,0],[4.32,.14,.14]);m.box('red',[0,3.57,.08],[4.15,.035,.025]);save(m)
m=Model('wall_accents')
for x in [-15.65,15.65]:
    for z in [-6,-1,4,9,14]:m.box('darkmetal',[x,2.25,z],[.06,2.5,.16]);m.box('violet' if z%2 else 'red',[x+(.036 if x<0 else -.036),2.25,z],[.015,2.15,.05])
save(m)
m=Model('plant');m.cyl('darkmetal',[0,.3,0],.3,.6,20);m.cyl('wood',[0,.9,0],.035,1.1,10)
for i in range(9):
    a=i*2.4;m.box('green',[.23*math.cos(a),.8+i*.055,.23*math.sin(a)],[.08,.65,.32],rz=.35*math.cos(a),ry=a)
save(m)
m=Model('lighting_rig')
for x,z,mat,c in [(-4,-4,'red',[1,.08,.14]),(4,-4,'violet',[.4,.16,1]),(-4,4,'violet',[.4,.16,1]),(4,4,'red',[1,.08,.14])]:
    m.box('darkmetal',[x,6.4,z],[1.5,.18,.25]);m.box(mat,[x,6.297,z],[1.3,.025,.12]);m.light('Dance_%s_%s'%(x,z),[x,5.6,z],c,2.0,10)
for z in [-1.5,7]:
    m.box('darkmetal',[-13.8,3.8,z],[.6,.15,.6]);m.box('amber',[-13.8,3.71,z],[.5,.025,.5]);m.light('Bar_%s'%z,[-13.4,3.3,z],[1,.63,.3],2.4,7)
m.light('Stage',[0,5.6,-14],[.65,.3,1],2,9)
m.light('Entry',[0,4.4,14],[.7,.76,1],1.8,10)
m.light('SocialLounge',[12,4,3],[1,.55,.45],1.9,10)
for x in [-11.5,11.5]:m.light('VIP_%s'%x,[x,3.8,-14],[.85,.4,.55],1.3,6)
save(m)
# Low-profile stair nosings stay visible under the nightclub lighting.
m=Model('step_markers')
for i in range(1,5):
    for side in [-1,1]:
        x=side*(8-(i-1)*.5-.03)
        m.box('amber',[x,.005+i*.2+.004,-13.5],[.04,.008,2.2])
for i in range(1,3):
    for x in [-11.5,11.5]:m.box('amber',[x,.005+i*.2+.004,-10-(i-1)*.5-.03],[2.2,.008,.04])
save(m)
# Emissive replacements preserve every original object's origin and exact geometry.
for name,size,mat in [('border_side',[.12,.002,16],'red'),('border_end',[13.76,.002,.12],'violet'),('inset_red',[.24,.001,3],'red'),('inset_violet',[.24,.001,3],'violet')]:
    m=Model(name);m.box(mat,[0,size[1]/2,0],size);save(m)
# Original 16-second musical loop; no downloaded recordings or licensed tracks.
rate=22050;seconds=16;random.seed(17);samples=[]
for n in range(rate*seconds):
    t=n/rate;beat=t/.5;phase=t%.5;v=0
    # Soft four-on-floor, offbeat hats, a warm bass/pad progression.
    if phase<.22:v+=.26*math.sin(math.tau*(48*phase+7*(1-math.exp(-phase*28))))*math.exp(-phase*22)
    hp=(t-.25)%.5
    if hp<.055:v+=(random.random()*2-1)*.035*math.exp(-hp*70)
    root=[55,43.6535,65.4064,48.9994][int(t//4)%4]
    v+=.07*math.sin(math.tau*root*t)*(.35+.65*math.exp(-phase*8))
    for ratio in [2,2.3784,2.9966]:v+=.018*math.sin(math.tau*root*ratio*t)
    # Keep loop endpoints smooth, retaining deterministic generated content.
    fade=min(1,t/.04,(seconds-t)/.04);samples.append(int(max(-.95,min(.95,v))*fade*32767))
with wave.open(str(OUT/'lumina_original_loop.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(struct.pack('<%dh'%len(samples),*samples))
(OUT/'manifest.json').write_text(json.dumps(MODELS,indent=2))
print('Prepared',len(MODELS),'original GLB modules and one original music loop;',sum(m['bytes'] for m in MODELS.values()),'model bytes')
