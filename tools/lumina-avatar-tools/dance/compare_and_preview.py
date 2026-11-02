import bpy,json,pathlib,math
from mathutils import Matrix,Quaternion,Vector
O=pathlib.Path(__file__).resolve().parent
native=json.loads((O/'corrected_native_poses.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath='C:/Users/Calla/Downloads/Dancing Twerk.fbx')
source=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');source.hide_render=True
S=Matrix(((1,0,0),(0,0,1),(0,-1,0))).to_4x4();C=S.inverted()
lookup={b.name.split(':')[-1]:b.name for b in source.data.bones}
pairs=[('Hips','Spine'),('Spine','Spine1'),('Spine1','Spine2'),('Spine2','Neck'),('Neck','Head')]
for side in ['Left','Right']:
 for a,b in [('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand'),('Hand','HandMiddle1'),('UpLeg','Leg'),('Leg','Foot'),('Foot','ToeBase')]:pairs.append((side+a,side+b))
errors=[];source_poses=[]
for idx,sample in enumerate(native['actual']['samples']):
 bpy.context.scene.frame_set(1+round(sample['time']*30));bpy.context.view_layer.update()
 sp={name:(S@source.matrix_world@source.pose.bones[full].matrix).translation for name,full in lookup.items()}
 source_poses.append(sp)
 for target in ['actual','canonical']:
  bones=native[target]['samples'][idx]['bones']
  for a,b in pairs:
   if a not in bones or b not in bones:continue
   d=Vector(bones[b]['position'])-Vector(bones[a]['position']);sd=sp[b]-sp[a]
   errors.append({'target':target,'time':sample['time'],'bone':a,'degrees':math.degrees(d.angle(sd))})
report={'max_degrees':max(e['degrees'] for e in errors),'comparisons':len(errors),'bake_ms':{k:v['bake_ms'] for k,v in native.items()},'worst':sorted(errors,key=lambda e:e['degrees'],reverse=True)[:12]}
(O/'source-comparison.json').write_text(json.dumps(report,indent=2));print('COMPARISON',json.dumps(report))
assert report['max_degrees']<0.1,report
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(O.parents[1]/'avatars/mpfb-test/Lumina_Test_Adult_Mirror_v3.glb'),disable_bone_shape=True)
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and o!=source)
avatar_root=bpy.data.objects.new('AvatarPreviewOffset',None);bpy.context.scene.collection.objects.link(avatar_root)
for obj in set(bpy.data.objects)-before-{avatar_root}:
 if obj.parent is None:obj.parent=avatar_root
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=1000;scene.render.resolution_y=650;scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.background_type='WORLD';scene.world.color=(.055,.055,.065)
camdata=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camdata);scene.collection.objects.link(cam);center=Vector((0,0,.95));cam.location=center+Vector((.5,-6,1.0));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=4.1;scene.camera=cam
for idx in [0,3,4]:
 bpy.context.view_layer.update()
 sample=native['actual']['samples'][idx]
 for bone in rig.pose.bones:
  entry=sample['bones'][bone.name];x,y,z,w=entry['rotation'];m=C@Quaternion((w,x,y,z)).to_matrix().to_4x4();m.translation=C.to_3x3()@Vector(entry['position'])
  bone.matrix=rig.matrix_world.inverted()@m;bpy.context.view_layer.update()
 avatar_root.location.x=1.05
 for o in list(bpy.data.objects):
  if o.name.startswith('SourceLine') or o.name.startswith('SourceHead'):bpy.data.objects.remove(o,do_unlink=True)
 sp=source_poses[idx];hiprest=(S@source.matrix_world@source.data.bones[lookup['Hips']].matrix_local).translation.y;scale=native['actual']['motion_scale']/hiprest
 def pos(n):return C.to_3x3()@(sp[n]*scale)+Vector((-1.05,0,0))
 for a,b in pairs+[('Spine2','LeftShoulder'),('Spine2','RightShoulder'),('Hips','LeftUpLeg'),('Hips','RightUpLeg')]:
  curve=bpy.data.curves.new('SourceLine','CURVE');curve.dimensions='3D';curve.bevel_depth=.018;curve.bevel_resolution=2;spl=curve.splines.new('POLY');spl.points.add(1)
  for p,v in zip(spl.points,[pos(a),pos(b)]):p.co=(*v,1)
  obj=bpy.data.objects.new('SourceLine',curve);scene.collection.objects.link(obj);obj.color=(.18,.7,1,1)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.095,location=pos('Head')+Vector((0,0,.07)));bpy.context.object.name='SourceHead';bpy.context.object.color=(.18,.7,1,1)
 scene.render.filepath=str(O/f'dance-corrected-{sample["time"]:g}s.png');bpy.ops.render.render(write_still=True)
 avatar_root.location.x=0
print('SOURCE_AND_CORRECTED_PREVIEWS_READY')
