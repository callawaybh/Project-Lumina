# Startup fixes: issues 2 and 3

## Diagnosed causes

Issue 2: GdSceneSynchronizer constructor calls rpc_id(1, "") before entering
any tree. Node::rpcp rejects it. Removed this empty-method RPC; both reliable
and unreliable RPC configurations remain unchanged. No valid RPC was deferred
or silently dropped.

Issue 3: the_mirror module attaches CollisionFxManager to TMSceneSync at SERVERS
initialization. Node::_validate_child_name needs node_hrcr_count to name the
unnamed child, but register_scene_types initializes that counter afterward.
Deferred only the attachment until MODULE_INITIALIZATION_LEVEL_SCENE. Singleton
creation, collision listener registration, and existing teardown remain intact.

Files:
- godot-engine/modules/network_synchronizer/godot4/gd_scene_synchronizer.cpp
  (nested NetworkSynchronizer submodule)
- godot-engine/modules/the_mirror/register_types.cpp

## Validation

- Previous #12-only build: startup RPC and name-counter errors reproduced;
  collision sound manager lacked a valid node name; fixture exited 1.
- New build: no startup RPC or name-counter error; collision manager parent/name
  checks pass; three extra synchronizer constructions and three setup/register/
  teardown cycles pass; fixture exits 0. Issue 12 remains absent.
- Incremental full engine build succeeded in 1m 03s at BelowNormal priority on
  two logical CPUs; diff whitespace checks pass.
- Existing debugger-file, teardown-disconnect and exit-leak messages remain.
- No editor or game was launched automatically; only tiny headless fixtures ran.
- This is not evidence that the unrestricted PC freeze is fixed.

## Deployment and next check

Protected test launcher now selects:
C:\Dev\LuminaBackups\godot-startup-fixes-2026-10-30.exe

Original binary remains restored at the normal engine/bin executable path.
Previous #12-only test binary and original backup are preserved. All native
source changes remain local/uncommitted across engine and nested submodule.

User should close existing Godot windows and use Test Rebuilt Editor (Protected).
First confirm editor startup without F5. Then arrange a watched game/world test.
Issue 11 is deliberately unchanged until this check is complete.
