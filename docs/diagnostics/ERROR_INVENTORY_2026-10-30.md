# Mirror runtime error inventory — October 30, 2026

Source: the user's supplied console output ending with a connected player and a
loaded profile. Some lines are clipped. Repeated instances and cascades are
grouped below; warnings are included because they are relevant to assessing the
implementation. This is an assessment, not a record of fixes applied.

Effort ranges estimate one engineer's focused investigation, fix and targeted
validation. They are not commitments or elapsed-time guarantees. Native-engine
investigations and newly discovered regressions can exceed these ranges.

| # | Error / warning | Meaning and likely impact | Likely fix / effort |
|---|---|---|---|
| 1 | OpenXR runtime/extension enumeration failures; OpenXR failed to initialize | Requested VR support could not initialize. Desktop fallback is explicit in the log. VR is unavailable; startup noise and possible startup delay, but not proof of a desktop loading failure. | Disable VR initialization in a desktop-only configuration, or separately configure a supported headset/runtime when VR is required. Small: 0.5–2 h for desktop handling; actual VR setup/testing is separate. |
| 2 | `!is_inside_tree()` in `Node::rpcp`; `ERR_UNCONFIGURED` | A network RPC was attempted before its node was inside the running scene tree. That call is rejected. Could be an isolated startup probe or a real initialization-order problem; its caller is not identified here. Also observed in a minimal headless fixture and the project manager, so not specific to the nightclub. | Trace the caller before deferring/reordering it or removing a startup probe. Investigation: 0.5–2 days; a native-engine correction/build may take longer. |
| 3 | `!node_hrcr_count.ref()` in `Node::_validate_child_name` | An internal engine counter check failed while generating a unique node name. The function aborts that path; this is not an ordinary warning that a designer chose the wrong name. Potentially affects node initialization/naming; actual downstream effect is not established. Also appeared in isolated engine startup. | Trace initialization/caller and compare the custom fork's engine changes. Investigation: 1–3 days; fix duration uncertain until traced. |
| 4 | Viewport texture `get_height` / `get_width`: texture must be set | UI code asks an unconfigured viewport-backed texture for its size. Can produce wrong/empty previews or layout dimensions. | Identify the owner and bind the viewport before querying, or safely defer the size query. Small: 1–4 h. |
| 5 | Invalid resource UIDs in six scenes | Resource identifiers are stale; several messages explicitly show fallback to text paths. Assets may still load, but moved/renamed resources become more fragile. | Rebind and save only the affected references; verify paths rather than wiping caches indiscriminately. Small: 1–3 h for all six. |
| 6 | Vanished inherited UI nodes: `TITLE`, `MarginContainer`, `Label` (two repeated groups) | Instanced scenes contain overrides for a header hierarchy no longer present in their base scene. Overrides are ignored; team-window headings/layout/customization may be wrong. | Reconcile base/instance scene hierarchy and remove stale overrides after checking intended appearance. Small/medium: 2–6 h. |
| 7 | `Invalid color name: .` | A value could not be interpreted as a named color. The final period is engine punctuation, so an empty string is a likely input. Visual-script registration converts an empty-string default to every struct type, including color, which is a concrete candidate. May create the wrong default color or affect generated block defaults. | Supply a valid typed color default and check generated block metadata. Small: 1–3 h. |
| 8 | Missing `VBoxContainer/Instructions` in `ScriptVariableEditor` | A script points to an absent instruction label. The reference is unused elsewhere in the current script, so likely stale startup noise rather than a broken variable editor by itself. | Remove the unused lookup or restore the intended label if required by the design. Very small: 15–60 min. |
| 9 | Missing `%CoverSpaceImage` on Home, My Spaces and Discover edit pages | Three instances of the same settings UI have a stale unique-node reference. It is unused elsewhere in the current script. Likely stale cover-image UI wiring rather than three separate defects. | Reconcile the image UI and remove or repair the stale reference; test all three pages. Small: 0.5–2 h. |
| 10 | Tree column indices 1 and 2 are out of bounds; only one column exists | The file browser sets titles for three columns before setting `tree.columns = 3`. Columns 1 and 2 reject their titles. Sorting labels/display can be wrong. | Set column count before accessing titles; verify sorting/display. Very small: 15–60 min. |
| 11 | Cannot create `net-sync-debugs/dump/debugger.py` (three instances) | The network debugger's helper UI cannot be written. In the current source, directory preparation returns early when dumping is disabled, but helper creation still runs. Its error macro returns safely; this message alone is not evidence of a null-file crash. Missing directories/permissions still need checking. Normal world loading can continue, but network-debugging support is incomplete. | Correct directory/setup gating or select a writable diagnostic location. Small: 1–3 h; native rebuild and regression checking may add time. |
| 12 | `/root/Zone/TMSceneSync` lacks `_setup_synchronizer` | A registered node has no expected hook for declaring synchronized properties. This could be an intentionally property-less native coordinator that is registered incorrectly, or a meaningful synchronization omission. The log cannot decide which. Potentially relevant to desynchronization and player-state corruption; no causation proven. | Audit coordinator registration and required state; do not silence it with an empty method without checking the contract. Medium/large: 1–3 days initially. |
| 13 | Legacy HTTP request `/user/me` on the game host | The tutorial handler runs on full login, including host login, and fetches the user's private profile through REST. `MirrorHttpClient` deliberately flags host-side REST calls. A warning does not itself establish request failure, but it is unnecessary host work and wrong-role UI initialization. This is distinct from the public `/user/id/...` lookup already migrated to WebSocket. | Prevent client tutorial startup on hosts; keep private-profile behavior on authenticated clients. Small: 0.5–2 h with host/client login checks. |
| 14 | Missing `PlayerCapsuleShape` | The player script looks up a node absent from the current scene. The lookup variable is unused, while the scene uses a Jolt shape resource, so this is likely stale code rather than proof the player has no collision. | Remove the obsolete lookup after confirming no dynamic references rely on it. Small: 0.5–2 h including collision checks. |
| 15 | Missing `VRController` | The player script looks up this child at ready time, but the local player's VR controller is created later by setup; hosts/other players need not have that child. Creates expected-absence errors and leaves a null reference until setup. Unguarded later access could cause real errors. | Initialize the reference explicitly, treat it as optional, and audit VR-specific calls. Small: 1–3 h for desktop paths; VR testing separate. |
| 16 | Self-RPC `load_equipables` rejected | The method is remote-only, but a host path attempts to send it to its own peer. The call is rejected; inventory/hotbar restoration may be skipped for that path. This does not prove equipment fails for every client. | Trace which peer/role triggers the call; dispatch locally or remotely as appropriate without broadly changing authority rules. Small/medium: 2–6 h. |

## Affected UID references

All paths below are relative to `mirror-godot-app/`:

- `creator/selection/inspector/primitive/inspector_subset.tscn`
- `creator/selection/inspector/primitive/inspector_texture_slider.tscn`
- `creator/common/asset_slot.tscn`
- `creator/tools/material_browser/material_browser.tscn`
- `creator/common/asset_slot_subwindow.tscn`
- `creator/tools/material_creator/material_creator.tscn`

## What is not an error

- TRACY being disabled: optional profiling is off.
- Engine/app version and Jolt layer-table lines: identification/loading information.
- `0/7` followed by `7/7`: an ordinary loading-progress transition.
- Backend login, websocket connection, listening on port 27015, physics ready,
  connected player, and loaded profile: successful milestones in this excerpt.

No recurring `zone_update_status` 404, NaN transform flood, or `LUMINA PLAYER FAULT`
appears in this supplied excerpt. Their absence here does not prove the intermittent
player-state bug has been fixed.

## Suggested order

1. Synchronizer setup (#12), RPC role/lifecycle errors (#16 and #2): investigate
   the correctness issues most plausibly connected to runtime instability.
2. Repair debugger capture/setup (#11), so the investigation has useful evidence.
3. Verify the internal node-counter error (#3) independently in a minimal startup.
4. Apply low-risk UI/role fixes (#8–10, #13–15), plus the typed color default (#7).
5. Reconcile resource references and inherited scenes (#4–6); keep desktop VR
   initialization quiet when VR is not requested (#1).

The order can overlap where fixes are independent. Do not infer one combined
delivery date by adding all estimates: some share a root cause, and the native
engine issues require investigation before a credible implementation estimate.

## Source evidence checked

- `scripts/net/mirror_http_client.gd`: deliberately flags host-side HTTP.
- `ui/user_tutorial/user_tutorial.gd`: private-profile request on full login.
- `creator/asset_inventory/browser/file_search.gd`: titles set before column count.
- `script/editor/variable/variable_editor.gd`: unused missing instruction lookup.
- `ui/main_menu/pages/edit_space/basic_settings.gd`: unused missing cover lookup.
- `player/player.gd` / `player/player.tscn`: stale capsule lookup and dynamic VR setup.
- `script/visual/visual_script_block_registration.gd`: empty defaults converted to struct types.
- Engine `core/math/color.cpp`: named-color error appends the final period.
- Engine `scene/main/node.cpp`: RPC tree requirement and naming-counter condition.
- `modules/network_synchronizer/godot4/gd_scene_synchronizer.cpp`: setup-hook contract.
- `modules/network_synchronizer/core/scene_synchronizer_debugger.cpp` and `ensure.h`:
  helper-file initialization and safe early return on failure.

No runtime code was modified for this assessment.
