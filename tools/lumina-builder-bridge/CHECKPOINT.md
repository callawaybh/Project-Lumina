# Lumina development checkpoint

This checkpoint adds the local builder bridge (creation, edits, naming,
duplication and persistent named collections), local startup/login fixes,
websocket public-profile requests, heartbeat acknowledgements, and safe handling
of maps without spawn markers.

Local performance settings cap the game at 60 FPS and two worker threads. The
local API uses 127.0.0.2 to bypass a stalled localhost/WSL forwarding path on this
Windows setup. Analytics are disabled only in the local environment.

The machine-specific `addons/mirror_internal/env_configs/local.cfg` is excluded
from this commit because it also contains credential fields. Its non-secret
local settings are `connection_server="http://127.0.0.2:9000"` and
`connection_server_ws="ws://127.0.0.2:9000"` under `[mirror]`,
`run/max_fps=60` under `[application]`, and `worker_pool/max_threads=2` under
`[threading]`. Existing local settings remain in the working checkout.

An intermittent player-state corruption caused invalid transforms and a console
flood. Its root cause is **not yet proven fixed**. Local-only guards now record
the first invalid stage and stop the runtime. Several subsequent world-entry
and exit cycles completed without triggering a report or runaway.

Validation completed:

- Seven Python bridge protocol/command tests.
- Seven targeted backend gateway tests; production TypeScript check.
- 150 isolated spawn trials.
- Production guard fixture: invalid values, bounded history, one report,
  local-only scope, and expected stop-on-fault exit.
- Godot script checks and live bridge persistence/restart tests.

Known remaining issues include startup synchronization warnings and renderer
resource-cleanup warnings on shutdown. This is a recoverable development
checkpoint, not a claim that the runtime is free of bugs.

`watch_lumina.ps1 -Continuous` passively monitors user-started game sessions for
up to 12 hours. It does not launch the game. It limits recognized game/host
processes to two logical CPUs at below-normal priority, records metrics, and
attempts a minidump before stopping a sustained hang or invalid-transform flood.
Editors and project managers are excluded. Use `-TestProcessIds PID` to include
an already-running game. Watcher process limits apply only while it is running;
the frame cap and worker-thread settings persist in the local environment file.

Diagnostic reports, bridge requests, dumps, local asset storage, environment
secrets, and generated import/animation changes are not part of this checkpoint.
