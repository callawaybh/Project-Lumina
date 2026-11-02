from pathlib import Path
import json
O=Path(__file__).resolve().parent
original=Path(r'C:\Dev\LuminaClient\tools\lumina-builder-bridge\nightclub\make_club_assets.py').read_text()
ns={'__file__':str(O/'generator.py')};exec(original.split('MODELS={}')[0],ns)
m=ns['Model']('club_effects_v1')
for x,z in [(-4.8,-5),(4.8,-5),(-4.8,4),(4.8,4)]:
 m.box('darkmetal',[x,6.43,z],[.48,.13,.45]);m.box('metal',[x,6.6,z],[.055,.25,.055])
for x in [-4.5,4.5]:
 m.box('black',[x,4.7,-10.05],[.42,.24,.35]);m.box('metal',[x,4.5,-10.05],[.04,.25,.04])
for x in [-5.5,5.5]:
 m.box('black',[x,.10,-9.6],[.5,.18,.4]);m.box('metal',[x,.11,-9.39],[.19,.08,.025])
m.extra.append({'name':'LUMINA_NIGHTCLUB_FX_V1','translation':[0,0,0]})
r=m.save();(O/'model-manifest.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
