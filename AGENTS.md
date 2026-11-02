# Project Lumina: instructions for future chats

## Start here

This is the Mirror Classic fork at `https://github.com/callawaybh/Project-Lumina`.
The development branch is `lumina-bootstrap`; the validated code checkpoint is
`534ce07`. Verify current Git state rather than resetting to that commit.

Read these before nightclub work:

1. `docs/nightclub/BUILD_PLAN.md` — recovered design, stages, and proposed layout.
2. `docs/nightclub/BRIDGE_RUNBOOK.md` — actual building interface and limitations.
3. `docs/nightclub/BUILD_STATE.json` and `BUILD_LOG.md` — progress and object IDs.
4. `tools/lumina-builder-bridge/CHECKPOINT.md` and `PLAYER_DIAGNOSTICS.md` when
   investigating startup, performance, or player faults.

## How to work with the user

- Use plain language. The user knows software but is new to GitHub/game development.
- Prefer the bridge/API, scripts, and file inspection over mouse/keyboard control
  for world construction. This bridge exists; do not restart an MCP/plugin search.
- **Do not launch the game, press Play, or run heavy tests automatically.** The
  user uses this PC for work and explicitly wants to press Play themselves. Say
  when F5 is needed and wait. Do not steal focus for routine checks.
- Give concise progress updates. Once a building stage is authorized, carry out
  its routine steps without asking permission for every primitive.
- These documents preserve a plan; they do not independently authorize starting
  construction. The nightclub construction is now saved; use BUILD_STATE.json for current status. The user authorized completing the remaining build without per-stage reviews.

## Runtime and preservation

- Current Windows checkout: `C:\Dev\LuminaClient`. Godot project:
  `C:\Dev\LuminaClient\mirror-godot-app`.
- Build into the running Mirror client's Space, not an unrelated Godot editor
  scene. Editing a `.tscn` alone does not populate the saved Mirror world.
- Space `luminara1`, ID `6ae4703d5754d729b3dbf699`, is the current candidate.
  Verify the running Space ID and inventory before any mutation. Preserve its
  map, sphere, and test primitives unless the user requests changing them.
- An intermittent player-state corruption caused NaN transforms and large error
  floods. Diagnostics now stop an affected local runtime and save a report.
  Subsequent repeated entries/exits passed, but the root cause is unproven.
- Keep local CPU limits and the passive watcher in mind; check actual processes
  and logs. Never assume a watcher from an earlier chat is still running.
- Do not reset/reclone, wipe Docker volumes, clear authentication, or rebuild the
  engine as routine troubleshooting. Inspect the specific failure first.
- Existing `.import` and animation `.tres` edits and machine-specific `local.cfg`
  were deliberately excluded from the checkpoint. Do not revert or commit them
  merely to make Git status clean.

## Building rules

- Use the installed Python CLI in `tools/lumina-builder-bridge`; see the runbook.
- Inventory first, prototype one module, verify it, then duplicate in small batches.
- Record every returned object/group ID in `BUILD_STATE.json` immediately. Names
  alone are not IDs and native duplication may suffix a name.
- Maintain `BUILD_LOG.md`: attempted batch, results, unresolved problems, next step.
- After a claimed-command timeout or partial group result, inspect state before
  retrying. Automatic replay can create duplicates.
- Use native authenticated persistence. Never mutate MongoDB directly as a normal
  building workflow or use an arbitrary-code execution bridge.
- Documented unsupported features need a narrow verified bridge extension before
  use. Do not claim a colored primitive is an actual light or emissive material.
- Checkpoint completion means saved-state verification plus user walk-through
  and reload testing when the user can run the game. Say which checks remain.

## Local access (November 1, 2026)

Read `docs/nightclub/LOCAL_ACCESS.md` for startup/authentication work. The local
client automatically loads the existing development profile without Firebase
sign-in. Keep the local-only session provider and normal permissions intact;
do not clear auth caches, recreate accounts, or replace Firebase configuration
to troubleshoot it. Hosted/non-local builds retain the normal login provider.
Live automatic-startup and Space-entry confirmation remains for the user.

## Completed nightclub construction

All nine construction stages were saved on November 1, 2026. The user waived
per-stage inspections; do not reintroduce them. Final user walkthrough, reload,
audio/seat behavior, performance, and two-player checks remain pending. Use
BUILD_STATE.json and the newest BUILD_LOG.md entries, rather than older checkpoint
paragraphs, to resolve status. Prepared-model import, material replacement, native
environment changes and feature inspection are now bridge capabilities; see the
updated runbook. No publishing or access changes are authorized by this build.

## Dance action

Hotbar slot 1 now contains the user-requested dance; see docs/avatars/DANCE_HOTBAR.md
and DANCE_STATE.json. Every client/host must use the updated player input/snapshot
layout. No engine rebuild is needed. The user confirmed the corrected single-player dance works. Minor shirt tearing
is deferred. The user confirmed the two-player LAN/tailnet test, including synchronized activity
and virtually no noticeable lag. This is user-reported, not instrumented latency.

## Nightclub effects

See docs/nightclub/EFFECTS.md and BUILD_STATE.json. The saved versioned fixture
contains a bundled client preset for four moving spots, two laser fans and two
smoke emitters. The user confirmed the effects work. Do not create a
second fixture to enable effects. Both clients need the source update; do not
claim GPU appearance or two-player verification based on headless checks.

## Two-player private-network test

The user authorized separate test login identities and a Windows guest client.
Read docs/nightclub/MULTIPLAYER_TEST.md and MULTIPLAYER_STATE.json before network,
authentication or guest packaging work. Owner profile/credentials are preserved;
Lumina Guest has visitor access only. The ignored owner settings contain the
host-only peer credential map and must never be shipped. The prepared guest ZIP
contains only its own credential. Do not launch either game automatically.
