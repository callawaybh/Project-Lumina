# First two-player Windows test

Prepared November 1, 2026 at the user's request. Both PCs share a LAN and tailnet.
Host: HOST-PC, Tailscale 100.64.0.10, LAN 192.168.1.10.
The online second Windows tailnet machine GUEST-PC (100.64.0.11)
responded over its direct LAN path in 5 ms. No remote machine was controlled and
no package was automatically sent. Use Tailscale for this test.

## User steps

Host PC: stop the current game, press F5, enter luminara1 and leave it running.
That restart is required to load the separate guest credential in the native host.

Second Windows PC: connect Tailscale, copy Lumina-Guest-Windows.zip from the notes
workspace multiplayer-setup folder, extract the entire archive, then double-click
Join Nightclub.cmd. It automatically authenticates as Lumina Guest and joins the
existing host via the normal Space deep link. No Docker, Blender or editor setup
is required. Do not run the launcher inside the ZIP or start a second backend.
The host must remain open; its normal quit closes the native local server.

Test seeing two distinct named players, movement, dance start/stop on both screens,
avatar loading, smoke/lighting performance and rejoining after closing the guest.
The first guest visit downloads the room's assets. A first-time tutorial may need
to be dismissed. Do not claim live two-player success until the user tests it.

## Identity and permissions

Owner stays 6ae46e485754d729b3dbf613 with existing ownership and selected v3 avatar.
Guest is 29e0de5410f1c49599a6012d, Lumina Guest, using the default astronaut.
The guest has an explicit OBSERVER (100) entry only for this Space. The default
Space role remains NO_ROLE (0); no publishing/access settings were opened broadly.

The development provider keeps the existing owner token mapping and accepts a
bounded LUMINA_LOCAL_DEV_PLAYERS JSON registry for separate configured test users.
Only explicitly provisionable entries can create their own profile through the
normal authenticated auth-user-create service. No direct database writes occur.
Existing/deleted profiles are not silently recreated. Ordinary role checks remain.
The native host reads local_dev_peer_tokens from its ignored local settings to
validate the guest token. The guest package contains only its own credential;
owner token, backend .env and host WSS secret are excluded. Do not publish this
package. The guest has its own LuminaGuestTest saved-settings directory.

Remote development mode requires env_name=local, explicit opt-in and an exact
configured private IPv4 host (RFC1918 or Tailscale CGNAT). API and socket URLs
must match that host or loopback; public/lookalike/userinfo URLs are rejected.
Hosted/non-development backend builds reject these test credentials.

## Same-session connection and assets

The guest's local_dev_join_space is the exact nightclub ID. Matching Space joins
connect directly to 100.64.0.10 UDP 27015 rather than asking the zone finder to
start another server. always_spin_up_local_server is false in the guest package.
The host retains its existing local-server startup route.

Guest REST/file traffic uses http://100.64.0.10:9000. Known saved localhost
assets-storage URLs are rewritten only for the HTTP transport; original URL/cache
keys stay intact. Other external downloads are unchanged. The existing firewall
rules already allow the host engine and Docker; no firewall or router changes
were made. No Tailscale Serve/Funnel or internet port forwarding was enabled.

The owner avatar was uploaded via native create-asset + public-file upload APIs
and its profile URL updated to that backend file, replacing the defunct temporary
127.0.0.1:8766 URL. This is the identical v3 model (no mesh changes). Asset/URL are
recorded in MULTIPLAYER_STATE.json. Guest file routing resolves its loopback origin.

## Checks and packaging

12 backend credential tests pass and production TypeScript checking passes.
33 isolated checks exercise the actual client provider and file resolver.
The integrated headless editor scan has no script parse/compile errors.
Live HTTP checks through the Tailscale address verified both distinct profiles,
90 saved objects, all 45 referenced assets and rejection of an unknown credential.
The guest's 500 imported-resource references and typed override settings pass.
Two unused stale importer records were excluded from the package only.
The archive is scanned for the exact owner token and WSS secret before delivery.

The portable folder contains the already rebuilt custom editor executable used
as a game runtime, source resources, imported resource cache and a guest override.
It avoids a new engine build or an export that could bake the owner's active
ProjectSettings into a pack. Neither the game nor an interactive client was
launched by the agent. GPU appearance and true two-PC gameplay remain pending.

## Recovery / maintenance

Backups: mirror-godot-app/.lumina-bridge/multiplayer-backup (contains secrets).
Never copy that directory into the guest package. The server registry is stored
in the backend ignored .env; matching native host settings are in ignored local.cfg
and override.cfg. Preserve the owner settings. Revocation means removing the guest
entry from both registries, restarting the backend and user-restarting the host.
Do not restore the old temporary avatar URL when reversing only authentication.

Source fixture/tool copies are under tools/lumina-builder-bridge/multiplayer.
Package and operator-facing instructions remain in the notes workspace.

## First guest attempt: stale host rejection

The guest reached the native game server and received AUTHENTICATION_FAILED.
An orphaned pre-update host (PID 23516, started 16:02) still owned UDP 27015.
The user's restarted client spawned host PID 9468 at 17:21, but that child could
not bind; ERR_CANT_CREATE had been silently ignored and its parent connected
to the old host. Both exact verified headless processes were stopped; the editor
and visible game were left under user control. UDP 27015 was released.

Host creation now includes a random startup ticket. A child writes a local
receipt only after binding, with PID, Space and port. The parent waits for that
exact child receipt before connecting; an unrelated older host cannot satisfy
it. Binding failures are logged and a failed child exits. Tests exercised the
production error branch on an actually occupied disposable ENet port plus
receipt PID/Space/port mismatch rejection. Integrated script scan passes.

Next step: user stops the game, presses F5 and re-enters luminara1. Verify the
new native host owns UDP 27015, then retry the guest. Existing guest ZIP remains
compatible; this correction affects only host startup, so no new transfer is
required. Actual two-player verification is still pending.

## Successful user test

The user confirmed both players joined the same room, player activity stayed in
sync and there was virtually no noticeable lag. Their screenshot shows both
avatars dancing in the finished nightclub with lights and smoke. This verifies
the first two-PC LAN/tailnet test; no numerical latency measurement, internet
load test, larger player count or synchronized music transport is claimed.

Public copy: device names and addresses above are illustrative replacements. Use the ignored local MULTIPLAYER_STATE.json for actual connection details.
