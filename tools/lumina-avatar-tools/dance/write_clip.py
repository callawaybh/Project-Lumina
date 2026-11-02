from pathlib import Path
import json
folder=Path(__file__).resolve().parent
d=json.loads((folder/'dance_samples.json').read_text());samples=d['samples'];report=d['report']
lines=['[gd_resource type="Animation" format=3]','','[resource]','resource_name = "Dancing Twerk"','length = '+str(report['length']),'step = 0.0333333333333','loop_mode = 1']
def track(index,bone,kind,values):
    lines.extend([f'tracks/{index}/type = "{kind}"',f'tracks/{index}/imported = false',f'tracks/{index}/enabled = true',f'tracks/{index}/path = NodePath("Armature/Skeleton3D:{bone}")',f'tracks/{index}/interp = 1',f'tracks/{index}/loop_wrap = true',f'tracks/{index}/keys = PackedFloat32Array('+', '.join(format(float(v),'.9g') for v in values)+')'])
track(0,'Hips','position_3d',[v for s in samples for v in [s['time'],1,*s['hips']]])
for index,bone in enumerate(report['bones'],1):track(index,bone,'rotation_3d',[v for s in samples for v in [s['time'],1,*s['rotation'][bone]]])
(folder/'dance_twerk.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
