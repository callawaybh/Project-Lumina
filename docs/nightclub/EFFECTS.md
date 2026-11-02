# Nightclub effects preset

Requested and installed November 1, 2026. The user confirmed the corrected dance
works; minor avatar shirt tearing is explicitly deferred.

## Saved world anchor

Space luminara1 (6ae4703d5754d729b3dbf699), origin [0,0,0], zero yaw.
Object LAD.S08.ClubEffects.001: 6ae7b422aa2be0959aa5d273.
Asset: 6ae7b422aa2be0959aa5d244. Group: LAD.S08.Effects (see BUILD_STATE.json).
Native Static body, collision disabled. The original 89 objects are preserved;
new inventory is 90 objects and 18 collections. Pre-change native REST snapshot:
notes workspace nightclub-effects/before-effects-snapshot.json.

## Rendering and behavior

Four real shadow-free SpotLight3D movers illuminate the central floor. Red and
violet translucent additive cone meshes make their shafts visible without
full-screen volumetric fog. Spot intensity pulses smoothly at 0.5 Hz; there is
no hard strobe. Two emissive laser fans have six thin mesh beams each, sweeping
from the rear toward endpoints constrained to the dance floor. They are visual
effects, not ray-traced lasers. Two soft CPUParticles3D emitters drift from the
front corners of the stage, totaling 96 particles with 8-second lifetimes.
Smoke depth tests normally and uses radial alpha textures and lifetime fades.
No global environment/fog, original music, layout or access settings changed.

A fixed GLB node marker LUMINA_NIGHTCLUB_FX_V1 opts this asset into a bundled
client preset. scaled_model.gd attaches club_effects.gd to that marker after
model construction. Imported assets cannot provide scripts or arbitrary commands.
The preset travels with the saved native asset on reload. No render nodes are
created on headless hosts. Each client runs the same 120-second master cycle
using wall-clock initial phase and monotonic elapsed time; clock skew can cause
phase differences. Smoke is cosmetic and not deterministic. Music beat/transport
synchronization is not implemented.

The real light budget grows from 11 point lights to 11 points + 4 spots, without
new shadow maps. No per-frame object network changes, physics bodies, collider
edits, room-wide fog or engine rebuild are required. Updated client code is
needed on both players' machines; the GLB alone contains the static fixtures.

## Verification and next action

307 isolated native-engine checks passed: native GLB marker import, light/particle
budgets, bounded intensity, finite transforms, laser endpoints, matching phases,
clock wrap continuity and idempotent setup. Full headless editor script scan had
no parse/compile errors. Headless checks do not compile GPU shaders or prove live
appearance, frame rate, smoke visibility, reload activation or multiplayer.

The running client predates this preset and currently shows only static housings.
User must stop and press F5, re-enter luminara1 in edit mode, and leave it open.
Then query inspect_object on the saved ID: club_effects should report four movers,
two fans and two smoke emitters; particles should report 48 each and emitting true.
Inspect actual rendering/performance and save any adjustments using this preset.
No extra fixture creation should occur on restart. Do not auto-launch gameplay.

Runtime: gameplay/space_object/effects/club_effects.gd and club_beam.gdshader.
Source generator and offline fixture retained in tools/lumina-builder-bridge/
nightclub/effects and the notes workspace nightclub-effects directory.
