from pathlib import Path
import math,json,struct,random,io
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
HERE=Path(__file__).resolve().parent;OUT=HERE/'models'
W,H=4096,2048;rng=np.random.default_rng(1047)
# Seamless, layered dust clouds; low resolution noise layers keep generation inexpensive.
noise=np.zeros((H,W),np.float32)
for gw,gh,weight in [(16,8,.46),(48,24,.27),(128,64,.17),(384,192,.10)]:
    a=rng.random((gh,gw),dtype=np.float32);a=np.concatenate([a,a[:,:1]],axis=1)
    tile=Image.fromarray(np.uint8(a*255)).resize((W+W//gw,H),Image.Resampling.BICUBIC)
    noise+=np.asarray(tile,dtype=np.float32)[:,:W]/255*weight
pixels=np.zeros((H,W,3),dtype=np.uint8)
longitude=np.linspace(-math.pi,math.pi,W,endpoint=False,dtype=np.float32)[None,:]
for start in range(0,H,128):
    lat=(.5-np.arange(start,min(start+128,H),dtype=np.float32)[:,None]/H)*math.pi
    # A great-circle ribbon, naturally continuous around the panorama seam.
    distance=np.sin(lat)*.64+np.cos(lat)*np.cos(longitude-.5)*.768
    band=np.exp(-(distance/.14)**2)
    dust=noise[start:start+len(lat)]
    density=np.clip((dust-.31)*2.1,0,1.2)*band
    filaments=(np.sin(longitude*8+lat*4+noise[start:start+len(lat)]*8)+1)*.5
    horizon=np.exp(-(lat/.2)**2)
    for c,(base,nebula) in enumerate([(3,29),(5,28),(13,51)]):
        pixels[start:start+len(lat),:,c]=np.clip(base+horizon*(4 if c!=2 else 7)+density*nebula+band*filaments*(1 if c==0 else 2),0,255)
image=Image.fromarray(pixels,'RGB');stars=Image.new('RGB',(W,H));draw=ImageDraw.Draw(stars)
r=random.Random(944)
for i in range(12500):
    u=r.random();latitude=math.asin(r.uniform(-1,1));v=.5-latitude/math.pi
    x=u*W;y=v*H;level=r.random();brightness=int(70+185*level**2)
    tint=r.choice([(1,.95,.86),(.78,.87,1),(1,1,1),(1,.86,.71)])
    col=tuple(int(brightness*c) for c in tint)
    radius=.35 if level<.94 else .7
    draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=col)
    if level>.996:
        draw.line((x-2,y,x+2,y),fill=tuple(int(c*.45) for c in col));draw.line((x,y-2,x,y+2),fill=tuple(int(c*.45) for c in col))
# Subtle halos around the few bright stars, without washing out the dark sky.
glow=stars.filter(ImageFilter.GaussianBlur(1.15))
base=np.asarray(image,dtype=np.uint16)+np.asarray(stars,dtype=np.uint16)+np.asarray(glow,dtype=np.uint16)//2
image=Image.fromarray(np.uint8(np.minimum(base,255)));image.save(HERE/'starry_panorama.png',optimize=True)
buf=io.BytesIO();image.save(buf,format='PNG',optimize=True);png=buf.getvalue()
# Standard embedded GLB: inward-facing sphere with one unlit panoramic material.
positions=[];normals=[];uv=[];indices=[];R=300;NX=160;NY=80
for j in range(NY+1):
    theta=j/NY*math.pi
    for i in range(NX+1):
        phi=i/NX*math.tau-math.pi
        p=[R*math.sin(theta)*math.sin(phi),R*math.cos(theta),R*math.sin(theta)*math.cos(phi)]
        positions.append(p);normals.append([-q/R for q in p]);uv.append([i/NX,j/NY])
for j in range(NY):
    for i in range(NX):
        a=j*(NX+1)+i;b=a+1;c=a+NX+1;d=c+1
        indices.extend([a,c,b,b,c,d])
data=bytearray();views=[];accessors=[]
def acc(values,width,kind=5126):
    while len(data)%4:data.append(0)
    offset=len(data);flat=values if width==1 else [v for p in values for v in p]
    data.extend(struct.pack('<%d%s'%(len(flat),'I' if kind==5125 else 'f'),*flat))
    views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':34963 if width==1 else 34962})
    item={'bufferView':len(views)-1,'componentType':kind,'count':len(values),'type':{1:'SCALAR',2:'VEC2',3:'VEC3'}[width]}
    if width==3:item.update(min=[min(p[i] for p in values) for i in range(3)],max=[max(p[i] for p in values) for i in range(3)])
    accessors.append(item);return len(accessors)-1
p=acc(positions,3);n=acc(normals,3);t=acc(uv,2);ind=acc(indices,1,5125)
while len(data)%4:data.append(0)
offset=len(data);data.extend(png);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(png)})
doc={'asset':{'version':'2.0','generator':'Lumina original panoramic star dome'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':'Lumina_Starry_Sky','mesh':0}],'meshes':[{'primitives':[{'attributes':{'POSITION':p,'NORMAL':n,'TEXCOORD_0':t},'indices':ind,'material':0}]}],'materials':[{'name':'Night_Stars_Unlit','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':1},'extensions':{'KHR_materials_unlit':{}}}],'textures':[{'sampler':0,'source':0}],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':33071}],'images':[{'bufferView':len(views)-1,'mimeType':'image/png'}],'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':accessors,'extensionsUsed':['KHR_materials_unlit']}
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);data+=b'\0'*((-len(data))%4)
glb=struct.pack('<III',0x46546c67,2,28+len(js)+len(data))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(data),0x004e4942)+data
(OUT/'starry_sky.glb').write_bytes(glb)
print('Original 4096 x 2048 panorama and unlit star dome prepared:',len(glb),'bytes')

manifest_path=OUT/"manifest.json"
manifest=json.loads(manifest_path.read_text())
manifest["starry_sky"]={"file":"starry_sky.glb","bounds":{"position":[-300,-300,-300],"size":[600,600,600]},"meshes":1,"emissive_surfaces":0,"seats":0,"lights":0,"bytes":len(glb)}
manifest_path.write_text(json.dumps(manifest,indent=2))
