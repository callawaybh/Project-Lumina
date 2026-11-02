# Lumina After Dark: design and staged build

## Approved design direction

Modern social nightclub: dark charcoal/black architecture, red and violet accents,
warm amber bar lighting, burgundy upholstery, black tables, brushed-metal trim.
Single level with shallow platforms, not a balcony or second floor.

- Room approximately **32 m wide × 40 m deep**, **7 m ceiling height**.
- Central **14 × 16 m dance floor**, dark with thin glowing borders and a few
  inset colored panels; not a checkerboard disco floor.
- Rear DJ platform approximately **0.8 m high**, with side access, broad console,
  speaker stacks, staggered vertical light bars, and a large **red crescent**.
- Long bar along the **left wall**, black stools, warm backlit shelves and edge.
- Social booths and low tables along the **right wall**, with softer lighting.
- Two shallow raised VIP seating areas flanking the stage, initially open to all.
- Entrance/lobby at the front; backstage/storage strip at the rear.
- Maintain at least **2 m clear circulation** around the dance floor. No central
  columns, avatar traps, or narrow bottlenecks. Keep steps and exits readable.

References are `references/entrance-concept.png` and `lounge-concept.png`.
They are concept renders, not proof of supported rendering features or an existing build.

## Asset strategy

Build the shell first and create assets as each stage needs them. Establish scale,
a placement grid, and the small palette first. Finish one bar/stool/booth/table
module, test it at avatar scale, then duplicate it. Avoid building a large asset
collection before learning what actually fits the room.

Favor reusable geometry, simple collision, static decoration, and emissive surfaces
over many dynamic lights. The current bridge cannot yet set emission, lights,
general collision/body setters, text, seating, music, or publish settings. Verify or extend
those capabilities at the relevant stage; do not invent commands or substitute
database edits. Prototype one architectural module and test collision/physics
stability before duplicating a shell. New bridge primitives explicitly use Static bodies with collision enabled.
Inspect imported/copied assets individually; no general body-mode setter exists.

## Proposed construction layout — to establish before building

The original concept did not fix a world anchor or every object's coordinates.
The following is a useful starting grid, not an already approved placement.
Choose an empty build area after inventorying the actual Space. Do not build
through the existing sphere, map features, or test objects.

Define club-local origin at the floor center, +Y up, front entrance at +Z, DJ
stage at -Z. A world anchor and orientation must be recorded in `BUILD_STATE.json`.
For the first version, prefer zero yaw so translating this grid is straightforward.
Do not send these local coordinates directly to the bridge until converted to
the chosen world placement.

| Zone | Proposed club-local extent / placement |
|---|---|
| Outer footprint | X -16…16, Z -20…20; floor surface Y=0, ceiling about Y=7 |
| Dance floor | X -7…7, Z -8…8 |
| Left/right main aisles | Reserve X -9…-7 and 7…9 alongside the dance floor |
| Entry/lobby | Front-center near Z 14…20 |
| Bar and stools | Left side, roughly X -15…-10, Z -7…12 |
| Social lounge | Right side, roughly X 10…15, Z -7…12 |
| DJ platform | Center rear, roughly X -6…6, Z -18…-11, surface Y≈0.8 |
| VIP platforms | Either side of DJ area, roughly X -15…-7 and 7…15, Z -17…-11 |
| Backstage/storage | Rear strip near Z -20…-18 |

Wall thickness, exact entrance dimensions, VIP height, stairs, furniture sizes and
roof/ceiling thickness remain implementation choices. Distinguish floor surface
height from a primitive's bottom-center position. A floor slab should not raise
the entire layout accidentally. Leave construction access to the interior.

## Nine build stages

| Stage | Scope | Verification / completion criterion |
|---|---|---|
| 1. Walls and roof | 32 × 40 m outer shell, entrance opening, roughly 7 m height. Roof kept in its own group for construction access. | Inspect anchor, module sizes and collision, then walk inside; verify avatar scale/camera clearance. |
| 2. Ceiling and floor | Dark floor, dance-floor surface and border geometry, ceiling panels and exposed beams. | Ground collision reliable; at least 2 m routes remain clear. Border geometry alone is not yet glowing. |
| 3. Stage and raised lounges | DJ platform, side stairs, two shallow VIP platforms. | Walk/jump to every area; no trapped corners or inaccessible platforms. |
| 4. Bar structure | Counter, back wall, bottle shelves, stools along left wall. | One module tested at avatar scale; enough gathering space behind stools. |
| 5. Seating and tables | Burgundy booths, black low tables, VIP seating; reusable groups. | Clear sightlines and circulation; no furniture traps. Sitting behavior is a separate capability check. |
| 6. DJ booth and signature features | Console, speaker stacks, segmented crescent, vertical light-bar geometry, club sign. | Entrance composition matches the references; custom text/emission/import needs are explicitly tracked. |
| 7. Materials and lighting | Charcoal finishes, burgundy upholstery, metal, red/violet accents, amber bar, actual emissive borders. | Extend/verify material/light APIs first; dark mood with readable faces, steps and exits, acceptable performance. |
| 8. Details and atmosphere | Bottles, glasses, plants, lamps, equipment, restrained supported atmosphere effects. | Add detail in small batches; check load time and performance. |
| 9. Functionality and final testing | Music, supported seating interactions, collision cleanup, multiplayer and persistence. | Test with two players when available; reload the world, verify saved state, back up completed work. Local audio alone does not prove synchronized music. |

Finish each stage with a concise walk-through/review opportunity and a recorded
checkpoint. Follow the user's current scope: permission for one stage does not
mean all later stages are authorized; permission for the entire build does not
require a new approval for every primitive. No stage is started by this document.

## Naming and modules

Use `LAD.S01.NorthWall.001`, `LAD.S03.DJPlatform.001`, etc. for objects, and
`LAD.S01.Shell`, `LAD.S01.Roof`, `LAD.S04.BarModule.001` for groups. Save actual
returned IDs and names; Mirror may suffix duplicates. Each stage should be easy
to identify without relying on object ordering.

Roof groups are bridge collections, not a visibility toggle. If temporarily
moving a roof for access, record exact original positions and restore them.
Explicit-ID deletion is available through the native bridge with a pre-delete
snapshot and saved-state verification. There is no undo/hide command. Only delete
within authorized cleanup/correction scope; do not use off-map relocation as deletion.

## Approved stage-one placement, November 1

User approved removal of all six test objects, retention of the checkerboard
ground, and construction at the current area: world anchor [0,0,0], zero yaw,
front +Z. Saved shell footprint is 32 × 40 m, wall height 7 m, thickness 0.3 m;
entrance is 4 m wide × 3.5 m high. Roof spans the footprint at Y=7…7.3 m and
has its own group. Only walls/roof have been built. User inspection and reload
are pending. BUILD_STATE.json is the authoritative object/group ledger.

## Stage-two checkpoint, November 1, 2026

The user approved the shell visually and requested continuation. Stage two is
saved in luminara1: dark floor top Y=0.005 m, 14 x 16 m dance surface top
Y=0.010 m, red/violet borders and four accent strips (maximum top Y=0.012 m),
four ceiling panels at Y=6.92-7 m, and five transverse beams at Y=6.65-6.92 m.
All 19 new pieces are static with collision enabled. The original ground and
seven shell pieces remain; total inventory is 27. The dance floor fits X +/-7
and Z +/-8, preserving the reserved two-metre side routes. Border/accent
geometry has no emission yet; lighting remains a later stage. Floor, DanceFloor,
and Ceiling are separate saved bridge groups. IDs and receipts are recorded in
BUILD_STATE.json. Saved inventory/groups and live positions/dimensions were
verified; walking/collision and reload tests remain for the user. Pause at this
review checkpoint before stage three (DJ platform, stairs, raised lounges).

## Stage-three checkpoint, November 1, 2026

The user visually approved stage two and requested continuation. Stage three is
saved: 12 x 6.7 m DJ platform at X=-6..6, Z=-17.7..-11, surface Y=.805;
two 7 x 6 m lounge platforms at X=-15..-8 / 8..15, Z=-17..-11, surface
Y=.405. Paired side stairs occupy X=-8..-6 / 6..8, Z=-14.7..-12.3; four
20 cm rises with 50 cm treads, 2.4 m wide. Each lounge also has a separate
forward entry with two 20 cm rises, 50 cm treads, and 2.4 m width. Platform
rises are relative to the Y=.005 finished floor. Two metres remain behind the
DJ platform and in front of lounge steps before the dance floor. No access
restrictions, furniture, console, rails, or lights were added at this stage.

15 static pieces were added in DJPlatform, StageAccess, and Lounges collections;
42 saved objects including original ground now exist. Native saved inventory
and group membership, live positions/dimensions, and collision-enabled static
settings were verified. The player is configured for 40 cm step climbing;
actual walking on the 20 cm stairs and reload verification remain for the user.
Pause here for inspection before the left-wall bar structure. All object/group
IDs and command receipts are in BUILD_STATE.json and BUILD_LOG.md.

## Completed construction checkpoint, November 1, 2026

The user authorized completing all remaining stages without per-stage inspection.
All nine construction stages are now saved, with final walkthrough/reload/two-player
tests explicitly pending. Earlier per-stage pause requests are superseded.

- Stage 4: left-wall panelled counter, metallic trim, amber emissive edge, bottle
  shelves, and six native seats on black/burgundy stools.
- Stage 5: four right-wall burgundy sofas with tables; two VIP sofas, two
  armchairs, and two tables. There is one interaction marker per seat object,
  including one centered marker per wide sofa. Decorative multi-cushion geometry
  does not imply three separately selectable seats on a sofa.
- Stage 6: detailed DJ console with decks/faders/laptop, paired speaker towers,
  red crescent, staggered red/violet light bars, exterior/interior club signs,
  exit sign, and entrance trim. The rear passage remains two metres wide.
- Stage 7: eight superseded dance borders/insets were replaced by verified fresh instances with emissive GLB
  materials; an imported rig provides eleven point lights with no shadows.
  Native saved environment uses no sun, restrained sky ambient, glow enabled,
  and no fog, SSR, or real-time global illumination.
- Stage 8: glasses/amber votive accents on tables, wall accents, and four plants.
- Stage 9: an original generated 16-second loop uses the native audio asset,
  autoplay/loop enabled at 18 percent volume. Each client autoplays independently;
  beat/phase synchronization is not implemented or claimed.

Stair edges use low-profile amber emissive markers. Cached model refresh ordering,
rotation-save numeric precision, and audio-spawn merge defaults were corrected
in source; the live build uses freshly loaded verified models and explicit settings.

All models were generated specifically for Lumina with embedded GLB geometry,
PBR materials, KHR_lights_punctual / KHR_materials_emissive_strength and native
OMI_seat metadata. The engine importer validated 23 reusable modules. Live
feature checks verified geometry bounds, emissive surface counts, seat metadata
and light settings; native REST verified saved objects/groups/environment.
The original ground and prior architecture remain. No publishing/access settings
were changed. The seating controller now guards optional custom script signals
so plain OMI seats do not emit nonexistent-event errors.

All IDs, receipts, model placements and checks are in BUILD_STATE.json. The
notes workspace holds completed-build-snapshot.json as a local native backup.
User walking/stairs/seating, audible music, final rendering/performance, reload
and a second-client session still need live confirmation. Do not mark these
checks complete based only on settings or backend persistence.

## Starry sky addition, November 1, 2026

User requested a beautiful starry sky above the club. Added LAD.S07.StarrySky.001
using the native bridge: original 4096 x 2048 blue/violet starfield panorama on
a 300 m-radius unlit, double-sided sphere, collision disabled. Separate group
LAD.S07.Sky. This is a visual panorama dome; it does not change HDR image-based
lighting or the existing environment settings. Native importer verified its
texture, unlit material, and inward visibility; native saved/live object checks
and a live exterior screenshot passed. Inventory: 89 objects, 17 groups.
The existing environment dictionary is unchanged. Reload check remains pending.
