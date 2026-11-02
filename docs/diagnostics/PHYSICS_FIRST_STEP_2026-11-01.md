# November 1, 2026 � native first-step physics failure

The user-run local-access trial reached the existing profile, started the local
host on port 27015, and loaded the Space. Host PID 21500 then triggered the
existing guard at `physics.native_result`, with finite position, zero incoming
velocity, finite positive timestep, zero movement input, and NaN outgoing
velocity. Report: `player-fault-21500-9202794.json` at 16:47:44 UTC.

An earlier report, `player-fault-29008-916223158.json` at 16:35:43 UTC, predates
the local-access changes and shows the same first-native-step velocity fault.
The latest stop therefore reproduces the earlier physics failure; this does not
prove authentication or avatar changes have no timing influence.

Concrete source defect: `TMCharacter3D::accumulated_impulses` was declared as a
default-constructed `JPH::Vec3`. Jolt documents that this default constructor is
intentionally uninitialized. `TMCharacter3D`'s constructor only sets mass.
`process_character` adds the uninitialized accumulator into velocity before
clearing it to zero. No prior initializer was found. This can contaminate the
first simulation step. It is a strong candidate for the captured fault; live
causality and resolution are not yet proven.

Prepared source fix: initialize the accumulator to `JPH::Vec3::sZero()` in
`modules/the_mirror/physics/tm_character_3d.h`. Keep all diagnostics enabled.
No engine build or subsequent live game run has been performed for this fix.
The currently installed executable still contains the old native code.

The user's editor is preserved. A targeted check for the failed client process
found it already gone, so no process was stopped by the agent. No auth cache,
user profile, Space record, or world object was edited for this investigation.

Next: user approval for a two-worker incremental native build; preserve the old
binary for rollback, then perform bounded isolated physics checks. The user
must launch the game themselves for the final validation. Do not call this fixed
merely because source initialization has been corrected.


## Build and validation result

The user approved rebuilding while the PC was not in use for work. A two-worker
incremental SCons build compiled the changed character code and dependent Mirror
objects. The first link encountered the running editor's locked executable;
the completed candidate was subsequently linked under `godot_impulsefix` using
a temporary output-name change in Windows SCsub. SCsub was restored afterward.
This build also incorporates the existing local native synchronization changes
already present in the checkout. No source changes were reverted.

The bounded isolated native fixture creates 24 fresh TMCharacter3D instances and
executes 96 physics steps, exercising idle, movement, explicit initial impulses,
and freed-object allocator reuse with an unconsumed pending impulse. The new
candidate passed all finite-state and fresh-character-no-inherited-impulse
checks. The old executable failed with `Fresh character inherited an earlier
object's pending impulse`. This provides a reproducer for the initialization
defect, although the exact captured user's NaN event still needs live retesting.

The candidate was installed at the canonical engine executable path and verified
by SHA-256 comparison. The previous main executable and console wrapper remain
in `godot-engine/bin` with the prefix
`godot.pre-impulsefix-20261101.windows.editor.x86_64` for rollback. Windows allowed
renaming the loaded executable, so the user's editor was not closed. The user
must close and reopen the editor to load the new native code before pressing F5.

The isolated candidate run still reports debugger-output-path, teardown signal,
and exit object-leak warnings. These checks do not establish a clean full game
run. No game was automatically launched, no guard disabled, and no world or
account data modified. Automatic local profile loading worked in the user run;
Space-entry stability and repeat-entry validation remain pending.

User follow-up: after reopening with the rebuilt engine, the user reported success and returned to in-Space avatar animation testing. This is one successful user-run confirmation; repeated entry/reload stability has not been established.
