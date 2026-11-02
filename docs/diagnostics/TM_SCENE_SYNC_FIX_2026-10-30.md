# Issue 12: TMSceneSync setup contract

## Cause

TMSceneSync::on_init_synchronizer registers the coordinator itself as an object
so its POST-phase callback can advance Jolt physics. Spatial relevance also
keeps this coordinator simulated. The generic GdSceneSynchronizer setup path
expects a GDScript _setup_synchronizer method on every registered object.
TMSceneSync has none because its process and contact snapshot callbacks are
implemented in native code.

## Change

Override setup_synchronizer_for in TMSceneSync. Only its own object handle
uses the native coordinator setup path. Every other registered object still
passes through GdSceneSynchronizer::setup_synchronizer_for, preserving missing
setup errors and player/object property registration. Do not unregister the
coordinator or suppress the generic warning globally.

Source files in engine submodule:
- modules/the_mirror/physics/tm_scene_sync.cpp
- modules/the_mirror/physics/tm_scene_sync.h

## Validation

- Small compiled harness using the extracted production method passed:
  virtual dispatch, coordinator registration/re-registration, and forwarding
  player/other-object handles and IDs to the base setup path.
- Native Mirror module compiled and linked successfully in the full build.
- git diff --check passed (Git reported only line-ending normalization notices).
- Full engine build succeeded. Initial compilation took 41m 52s under the CPU cap; after user closed the editor, the final build/link retry completed in 45s.
- This does not establish the cause of the intermittent NaN/CPU runaway.

Build configuration matches the recorded environment: Windows editor x86_64,
production=yes, optimize=speed, debug_symbols=no, lto=none. SCons uses two jobs;
the build parent and its compiler children have affinity mask 3 (two logical
processors) and BelowNormal priority.

After build completion, user should reopen the custom editor, press F5, enter
and exit the test space, and provide logs for confirmation that the specific
TMSceneSync missing-_setup_synchronizer error is absent. Other numbered issues
remain separate.

Rollback executable: C:\Dev\LuminaBackups\godot-before-sync-setup-fix-2026-10-30.exe
Old-engine headless baseline reproduced the coordinator missing-method error in all three setup cycles. The fixture also exposes existing startup/debugger/teardown messages; those are outside issue 12.


## Completed engine regression

Identical headless fixture on saved original and rebuilt executable:
- Original: three coordinator missing-method errors.
- Rebuilt: zero coordinator missing-method errors.
- Both: ordinary object setup callback ran exactly once per registration; repeated registration did not duplicate setup; three setup/teardown cycles completed; exit code 0.
- Existing native startup assertions, debugger file errors, teardown disconnect errors, and shutdown leak warning remain in both logs. They are not fixed by this patch.

New executable length: 123539456 bytes.
SHA256: DDA9383EB1B053957C25A589473F0D4496B49617B038256E6D18DF58F1CB20DD

Live world-entry/exit validation remains pending a user-started game. Source changes are local and uncommitted in the godot-engine submodule.


## Deployment rolled back after PC freeze

User reported that opening the project through Godot's project list froze the
PC before pressing F5. Closing Godot restored PC responsiveness. No Godot
process remained when inspected. No automatic editor/game launch was performed.

The rebuilt executable was preserved at:
C:\Dev\LuminaBackups\godot-sync-setup-fix-investigation-2026-10-30.exe

The original executable was restored to the normal engine bin path and its
SHA256 was verified against the pre-build backup. Native source fix remains
local and uncommitted. Issue 12 will remain in the restored executable.

Latest Mirror logs are small (about 7 KB and 12 KB), contain login/asset-search
startup, and do not establish an invalid-transform flood or the CPU cause.
Editor project_metadata.cfg was last modified before this attempt. User confirms
opening through the project list; do not dismiss their report as a launch error.
No live CPU/memory measurements were captured during the freeze.

The headless setup regression is still a valid narrow before/after result, but
it did not validate editor/project startup or system resource use. Full project
stability is unverified and the rebuilt binary must not be redeployed merely
because the isolated test passed. Any future comparison should use user-started,
resource-contained launches and collect per-process CPU, memory and startup logs.

## Protected old-engine editor baseline

User opened restored original engine using protected launcher and reported normal
editor startup. First 28 samples: all Responding=True; CPU peak 10.79% of PC,
average 1.36%, then about 0.1-0.3%; private committed memory about 2566-2568 MB,
working set about 1328 MB. Two-core affinity mask 3 and BelowNormal priority held.
Editor log was small and contained existing startup/UID errors, no error flood.
This is an old-engine limited-startup baseline, not validation of the rebuilt
engine. A separate user-operated patched launcher selects the preserved rebuilt
binary without replacing the restored working executable. It refuses to start
while any Godot process is present. No editor or game was launched by Codex.

## Protected rebuilt-editor baseline

User reports normal and stable editor startup with the preserved rebuilt binary.
82 sampled readings: peak CPU 11.73% of PC, mean 0.82%; working set settled at
about 1385 MB, private memory about 2619 MB. Four early startup readings reported
Responding=False; final readings were responsive with CPU about 0-0.1%. The
small editor log stopped growing after startup. This supports stability for this
limited editor session, not a root-cause diagnosis of the unrestricted freeze.
The restored old engine remains at the normal bin path. F5 from the patched
editor should use the preserved rebuilt binary; verify process paths at runtime.

## User-started rebuilt-engine live check

User reports game working well. Passive watcher observed game PID 17968 and host
PID 8716 on 2026-10-30 at 23:01 Eastern, with two-core affinity and BelowNormal
priority. All recorded game/host samples were responsive; after loading CPU
settled around 1-2% of PC, game working set around 1176 MB, host around 776 MB.
Both game and host subsequently exited; editor remained responsive.

Current host log confirms 7/7 world objects loaded, server object loading took
2 seconds, and physics became ready. Across three recent session log files:
zero coordinator missing-_setup_synchronizer errors, zero invalid-transform
matches, and zero websocket 404 matches. Existing shutdown cleanup errors remain.
This validates issue 12 in the limited live session. It does not establish the
cause of the earlier unrestricted startup freeze or prove long-term stability.

Deployment still uses the preserved rebuilt executable via the protected test
launcher. The normal bin executable remains the restored old binary; do not
claim the fix is installed there. No commit or push performed.
