# Local player-state diagnostics

Checks are enabled only when `mirror/env_name` is `local`, outside the editor.
They cover spawn transforms, teleport destinations, collected and decoded input,
native physics results, network snapshots/interpolation, and model interpolation.
Zero model scales and zero physics timesteps are checked; zero animation update
timesteps remain valid for teleports.

On the first invalid state for a player, the guard writes a JSON report under
`mirror-godot-app/.lumina-bridge/diagnostics/player-fault-PID-TIMESTAMP.json`.
It records the invalid field, stage, last twelve valid checks, role and call stack.
Non-finite values are represented as strings. Credentials and process arguments
are not recorded. This directory is already ignored by Git.

The affected player stops processing and is hidden. A host exits; a client uses
the existing quit path, which also closes its child local host. The editor is
not closed. This contains the failure rather than attempting to repair a corrupt
physics state or silently continue with fabricated positions.

Useful first-failure stages:

- `spawn.received` / `spawn.marker`: invalid spawn data.
- `physics.decoded_inputs`: bad input values before simulation.
- `physics.native_result`: state became invalid during the native physics call.
- `network.decoded_snapshot`: invalid values received in a network snapshot.
- `network.interpolated_result`: interpolation produced an invalid body transform.
- `network.late_update` / `frame.entry`: invalid state already present at a callback boundary.
- `model.update_status` / `model.frame_entry` / `model.interpolation_result`: invalid model, camera, scale, or look-target state.

Validation: full Godot script scan, isolated production-guard test (including
expected exit code 2, one-report behavior and non-local bypass), and 150 valid
spawn trials. The real intermittently failing session must still be observed.
