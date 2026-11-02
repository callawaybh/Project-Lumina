# Bridge building runbook for future chats

## What this is

This is an installed **local JSON-file command bridge** to a running Mirror
client. It is not a Godot MCP plugin, remote HTTP service, or arbitrary-code
console. Agents use the Python CLI through command/file tools. UI automation is
not the primary construction method. A chat must have access to this same local
Windows filesystem; access to GitHub alone cannot control the running world.

| Item | Current location |
|---|---|
| Repository | `C:\Dev\LuminaClient` |
| Godot project | `C:\Dev\LuminaClient\mirror-godot-app` |
| Python CLI | `C:\Dev\LuminaClient\tools\lumina-builder-bridge\bridge.py` |
| Autoload implementation | `mirror-godot-app/scripts/autoload/lumina_bridge.gd` |
| Runtime inbox/receipts | `mirror-godot-app/.lumina-bridge/` (ignored) |
| Current candidate Space | `luminara1`, `6ae4703d5754d729b3dbf699` |
| Existing bridge checkpoint | `534ce07`, branch `lumina-bootstrap` |

Use the compiled Mirror engine for gameplay, not a generic downloaded Godot:
`C:\Dev\LuminaClient\godot-engine\bin\godot.windows.editor.x86_64.exe`.
Engine source was pinned at `13b5ad644361de1675b368740e021ea4919a8f42`.
Do not rebuild it just to use the bridge.

The backend normally runs in Docker as `the_mirror_server`, `mongodb`, and `redis`.
On this installation Docker's executable is
`C:\Users\Calla\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe`.
Use installed service tools where available. Machine-specific local config uses
`http://127.0.0.2:9000` / `ws://127.0.0.2:9000`; this bypassed broken WSL forwarding
on localhost. See the checkpoint notes rather than replacing the Firebase setup.

## Preflight — read-only until the correct Space is confirmed

1. Read `AGENTS.md`, the build plan, state, log, and CLI help. Inspect Git status;
   a dirty checkout with known local/generated changes is expected.
2. Check whether the game and native local host are already running. Do not
   launch more instances. If Play is needed, ask the user to press F5 and wait.
3. Check the enable marker and actual environment. The bridge runs only in the
   local environment of an editor-capable **client**, not a host process.
4. Query status using a short timeout. A timeout before claim cancels the query;
   do not repeatedly queue commands into a closed game.
5. Local development automatically loads the existing profile; see LOCAL_ACCESS.md. If signed out unexpectedly, inspect the local session provider. Do not recreate accounts or clear saved auth
   as a routine fix. The account created through Mirror's API has a database-style
   Firebase UID; an unrelated Firebase-console account previously failed.
6. If the user has authorized entering the Space, use `join_space` from the home
   screen or let the user enter it. Wait for `ready=true`. Verify Space ID and
   edit mode; inventory objects/groups before changing anything.
7. Check the current player-fault report directory and watcher status. Do not
   proceed with building while the game is corrupt, restarting, or flooding logs.

```powershell
$bridgeScript = 'C:\Dev\LuminaClient\tools\lumina-builder-bridge\bridge.py'
$godotProject = 'C:\Dev\LuminaClient\mirror-godot-app'
py -3.12 $bridgeScript --help
py -3.12 $bridgeScript --project $godotProject --timeout 5 status
py -3.12 $bridgeScript --project $godotProject list_objects
py -3.12 $bridgeScript --project $godotProject list_groups
```

If the bridge is deliberately disabled, `enable` creates its marker and `disable`
removes it. Enabling does not launch the game or sign in. When a newly installed
autoload requires restarting, ask the user to do the Play step.

```powershell
py -3.12 $bridgeScript --project $godotProject enable
py -3.12 $bridgeScript --project $godotProject join_space 6ae4703d5754d729b3dbf699
```

Do not join over another loaded Space. `join_space` returns `state=joining`, not
proof that loading succeeded. Poll status sparingly, then verify the inventory.

## Current commands

Global options (`--project`, `--timeout`) go **before** the command name.
The examples below illustrate syntax; do not execute mutation examples without
the relevant building scope and a verified placement anchor.

```powershell
py -3.12 $bridgeScript create_primitive --name 'LAD.S01.WallPrototype.001' --shape box --position 100 0 100 --size 4 7 0.25 --color 0.05 0.05 0.06 1
py -3.12 $bridgeScript update_object OBJECT_ID --position 104 0 100
py -3.12 $bridgeScript update_object OBJECT_ID --rotation 0 1.5707963268 0
py -3.12 $bridgeScript update_object OBJECT_ID --scale 1 1 1
py -3.12 $bridgeScript update_object OBJECT_ID --color 0.15 0.02 0.03 1
py -3.12 $bridgeScript rename_object OBJECT_ID 'LAD.S01.WallPrototype.001'
py -3.12 $bridgeScript duplicate_object OBJECT_ID --name 'LAD.S01.WallPrototype.002' --offset 4 0 0
py -3.12 $bridgeScript create_group 'LAD.S01.Shell' OBJECT_ID_1 OBJECT_ID_2
py -3.12 $bridgeScript rename_group GROUP_ID 'LAD.S01.NorthWall'
py -3.12 $bridgeScript move_group GROUP_ID --offset 0 0 -4
py -3.12 $bridgeScript duplicate_group GROUP_ID 'LAD.S01.SouthWall' --offset 0 0 40
```

Replace IDs and coordinates with actual values; the 100 m example is not a chosen
club location. Shapes: `box`, `sphere`, `cylinder`. Units are meters and rotation
is radians. RGBA values are 0…1. Creation uses the primitive's **bottom center**.
Box size is X/Y/Z; sphere diameter uses size X; cylinder diameter uses X and
height uses Y. Scale must be positive. Keep architecture prototypes at unit scale
where possible and choose dimensions during creation.

Creation exports/uploads a GLB and waits for a native spawn receipt. A successful
result includes `object_id` and `asset_id`; save them immediately. Updates confirm
saved backend values. Recoloring bridge-created primitives rebuilds their model
asset; it does not use the ineffective legacy `objectColor` display field.
Geometry recipes in the ignored inbox enable later recoloring. Preserve that
folder when moving the development checkout; Git does not back it up.

## Reuse and grouping

Duplicate a verified module rather than uploading the same primitive repeatedly.
Copies reuse the asset and get independent object IDs. Existing native properties,
including scripts/physics settings when present, can be inherited by duplication;
inspect the source rather than treating every arbitrary object as a clean module.

Groups are named collections saved in Space custom data under `luminaBuilderGroups`.
They are not visible parent nodes in Mirror's scene hierarchy. Group names must
be unique and groups contain 1–100 unique editable object IDs. Whole-group moves
are translations only; copies preserve spacing. Groups can overlap. Use one
bridge client at a time because metadata is read-modify-write.

There is no nested grouping, membership-edit command, whole-group rotation/scale,
undo, hide toggle, or general transaction/rollback in this version.
There is also no arbitrary custom-model import, real-light placement, material
emission, text generation, collision/body-mode setter, audio, seating, or publishing
command. If a stage needs one, implement a narrow native-API extension and verify
it before promising the feature. Never bypass the native permission/persistence
path by writing directly to MongoDB as a normal building method.

## Batch workflow and recovery

1. Create one named prototype and record its ID/asset ID.
2. Verify dimensions, actual position, collisions, and stability at avatar scale.
3. Duplicate in small sequential batches. Do not submit overlapping mutation
   batches through multiple agents/clients.
4. After every successful mutation, update `BUILD_STATE.json` and append a concise
   result to `BUILD_LOG.md`; verify with fresh lists.
5. At a stage checkpoint, have the user walk through. When they can run a reload,
   verify that objects/groups persist. Do not restart gameplay automatically.

Requests use unique IDs, are atomically claimed before side effects, and are never
automatically replayed. A claimed timeout has an **unknown outcome**: inspect
inventory and the matching receipt before retrying. A group operation can succeed
for some members and fail for others; its response lists completed work. Never
blindly repeat it. Raise the CLI timeout for a deliberately larger sequential
group operation rather than retrying a still-running one.

The latest world object/group lists plus saved receipts are the source of truth
if the handoff state disagrees with the actual world. Preserve other people's
objects unless the user authorizes cleanup. On November 1 the user authorized removal
of the six non-map test objects; the ground remains protected.

## Runtime trouble

`LUMINA PLAYER FAULT` is the local guard deliberately stopping an invalid session.
Read the new `player-fault-*.json` under the ignored diagnostics folder, especially
`fault.stage`, `invalid_field`, `preceding_checks` and `stack`. Do not simply disable
the guard, retry the same mutation, or claim the intermittent bug is fixed.

The passive watcher is `tools/lumina-builder-bridge/watch_lumina.ps1 -Continuous`.
It never launches the game. Check for an existing watcher before starting another.
It applies two-logical-CPU affinity and below-normal priority to recognized games
and hosts, skips editors/project managers, and attempts a dump before stopping a
sustained window hang or invalid-transform log flood. Use `-TestProcessIds PID`
for an already-running game; obtain current IDs, never reuse old chat IDs.

Several world-entry/exit cycles passed after diagnostics were installed. That is
evidence of a stable test period, not proof of the corruption's root-cause repair.
Some startup/synchronization and renderer shutdown warnings remain.

## November 1 shell extension and checkpoint

`create_primitive` now explicitly spawns Static bodies with collision enabled.
`list_objects` reports live body type, collision setting, and merged mesh world
bounds. Bounds can temporarily include loading-placeholder geometry immediately
after a spawn receipt; wait and repeat read-only checks before judging dimensions.
Never repeat a creation command to resolve this transient mismatch.

`delete_objects --space-id SPACE_ID OBJECT_ID ...` accepts 1–32 explicit unique
IDs, verifies current Space/membership/edit permission, protects names beginning
`Map `, snapshots objects/groups to the ignored inbox, uses native delete packets,
and verifies saved and live removal. Deleted members are pruned from bridge groups;
empty groups are removed through native saved custom data. There is no undo command.
Use deletion only within explicit user-authorized cleanup/correction scope.

Stage one is saved and awaits user inspection: six wall/header pieces, one roof,
and the retained original ground. The shell and roof have separate collections.
BUILD_STATE.json contains all IDs and command receipts. Walkthrough/collision and
reload checks remain pending; no later build stages are authorized.

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

### Finishing bridge commands

Prepared assets are filenames inside `.lumina-bridge/models`; only GLB models and
WAV audio are accepted, under 15 MiB, with an exact current Space ID. Paths and
arbitrary scripts are rejected. Creation supports an initial rotation and an
explicit non-collision option. Model coordinates use the asset origin, unlike
primitive bottom-center creation. Original modules and generators are retained
in `tools/lumina-builder-bridge/nightclub/models` and the sibling Python sources.

```powershell
py -3.12 $bridgeScript create_model --space-id SPACE_ID --file sofa.glb --name 'Example Sofa' --position 0 0 0 --rotation 0 0 0
py -3.12 $bridgeScript inspect_object OBJECT_ID
py -3.12 $bridgeScript replace_model OBJECT_ID --space-id SPACE_ID --file border_side.glb
py -3.12 $bridgeScript create_audio --space-id SPACE_ID --file lumina_original_loop.wav --name 'Example Music' --position 0 2 0 --no-collision
```

These are syntax examples, not authorization to duplicate the finished build.
`set_environment` accepts `--space-id` and `--changes-json`; only a small whitelist
of club atmosphere fields is supported. It saves an environment snapshot before
sending the native change packet and confirms the saved result. Imported audio
uses native autoplay/loop, non-spatial playback at 18 percent volume. This does
not implement synchronized transport between clients.

`inspect_object` reports live mesh/emissive-surface/seat/light counts, static body
and collision settings, and mesh bounds. Native replicated Euler angles can wrap
at +/-pi and are quantized; verify equivalent angles within .002 rad, then compare
geometry bounds against the actual live pose. Do not enlarge or duplicate models
to compensate for these angle encodings.

Native fixes added during finishing: cached asset replacement now populates the
new file promise before setting up the model; saved numeric comparisons allow
1e-5 precision while keeping IDs exact; audio defaults overwrite the generic
collision setting; optional seat script events are emitted only when registered.
The live build used fresh verified accent instances to avoid relying on the
older running cached-refresh code. These source corrections load on the next
normal user-controlled restart; another restart is not required to see this build.

Verification artifacts in the local notes workspace: asset-validation-final.log
(23 imported modules), bridge-input-validation.log, saved-precision.log,
cached-refresh-validation.log (original failure versus corrected setup ordering),
and finishing-final-parse.log. Protocol suite: seven tests passed. Engine shutdown
resource warnings remain; no script parse/compile errors were found in the final
scan. Final recorded inventory: 88 objects including ground, 16 saved groups.
