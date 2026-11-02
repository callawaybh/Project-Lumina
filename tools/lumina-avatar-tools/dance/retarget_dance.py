"""Retarget the user's Mixamo dance onto Mirror's canonical humanoid bind axes."""
import bpy,json,pathlib,math
from mathutils import Matrix,Quaternion,Vector
OUT=pathlib.Path(__file__).resolve().parent
REF=OUT/'reference_rig.json'
ref=json.loads(REF.read_text())['reference']['bones']
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath='C:/Users/Calla/Downloads/Dancing Twerk.fbx')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');scene=bpy.context.scene
start,end=map(int,rig.animation_data.action.frame_range);fps=30;count=end-start+1;length=(count-1)/fps
C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
def mat_godot(matrix):return C.to_4x4()@matrix
source={b.name.split(':')[-1]:b for b in rig.data.bones}
matched=[name for name in ref if name in source]
source_rest={name:mat_godot(rig.matrix_world@source[name].matrix_local) for name in matched}
primary={'Hips':'Spine','Spine':'Spine1','Spine1':'Spine2','Spine2':'Neck','Neck':'Head','Head':'HeadTop_End'}
for side in ['Left','Right']:
    for a,b in [('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand'),('Hand','HandMiddle1'),('UpLeg','Leg'),('Leg','Foot'),('Foot','ToeBase'),('ToeBase','Toe_End')]:primary[side+a]=side+b
    for finger in ['Thumb','Index','Middle','Ring','Pinky']:
        for i in range(1,4):primary[side+'Hand'+finger+str(i)]=side+'Hand'+finger+str(i+1)
target_rest={};corrections={}
for name in matched:
    target_q=Quaternion((ref[name]['global_rotation'][3],*ref[name]['global_rotation'][:3]))
    child=primary.get(name)
    correction=Quaternion()
    if child in source and child in ref:
        source_direction=(mat_godot(rig.matrix_world@source[child].matrix_local).translation-source_rest[name].translation).normalized()
        target_direction=(Vector(ref[child]['global_position'])-Vector(ref[name]['global_position'])).normalized()
        correction=target_direction.rotation_difference(source_direction)
    corrections[name]=correction
    target_rest[name]=correction@target_q

height_ratio=ref['Hips']['global_position'][1]/source_rest['Hips'].translation.y
samples=[]
for frame in range(start,end+1):
    scene.frame_set(frame);glob={}
    for name in matched:
        bone=rig.pose.bones[source[name].name]
        animated=mat_godot(rig.matrix_world@bone.matrix).to_quaternion().normalized()
        glob[name]=(animated@source_rest[name].to_quaternion().inverted()@target_rest[name]).normalized()
    rotations={}
    for name in matched:
        parent=ref[name]['parent']
        q=(glob[parent].inverted()@glob[name]).normalized() if parent in glob else glob[name]
        if samples:
            prev=Quaternion((samples[-1]['rotation'][name][3],*samples[-1]['rotation'][name][:3]))
            if q.dot(prev)<0:q.negate()
        rotations[name]=[q.x,q.y,q.z,q.w]
    hips=mat_godot(rig.matrix_world@rig.pose.bones[source['Hips'].name].matrix).translation
    delta=(hips-source_rest['Hips'].translation)*height_ratio
    samples.append({'time':(frame-start)/fps,'rotation':rotations,'hips_delta':list(delta)})
# Keep the physical player stationary; remove only the clip's net horizontal travel.
a=Vector(samples[0]['hips_delta']);z=Vector(samples[-1]['hips_delta'])
for sample in samples:
    t=sample['time']/length;hip=Vector(sample['hips_delta'])
    hip.x-=a.x+(z.x-a.x)*t;hip.z-=a.z+(z.z-a.z)*t
    sample['hips']=[ref['Hips']['position'][i]+hip[i] for i in range(3)]
# Blend the last 0.2 seconds to the first sample, making the supplied clip a clean loop.
seam=.2
for sample in samples:
    weight=max(0,min(1,(sample['time']-(length-seam))/seam))
    if weight:
        sample['hips']=list(Vector(sample['hips']).lerp(Vector(samples[0]['hips']),weight))
        for name in matched:
            q=sample['rotation'][name];first=samples[0]['rotation'][name]
            q=Quaternion((q[3],*q[:3])).slerp(Quaternion((first[3],*first[:3])),weight).normalized()
            sample['rotation'][name]=[q.x,q.y,q.z,q.w]
report={'source':'Dancing Twerk.fbx','fps':fps,'length':length,'sample_count':len(samples),'bones':matched,'missing_target_bones':[n for n in ref if n not in source],'height_ratio':height_ratio,'horizontal_net_travel_removed_m':[z.x-a.x,z.z-a.z],'hips_y_range':[min(s['hips'][1] for s in samples),max(s['hips'][1] for s in samples)],'seam_blend_seconds':seam,'rest_pose_direction_correction':True}
(OUT/'dance_samples.json').write_text(json.dumps({'report':report,'samples':samples},separators=(',',':')))
print('LUMINA_DANCE_RETARGET',json.dumps(report))
