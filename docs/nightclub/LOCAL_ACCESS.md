# Local development access

Installed November 1, 2026. The local client now automatically connects using
the existing development profile `6ae46e485754d729b3dbf613`. It does not require
an email/password or contact Firebase Auth to sign in. Existing Spaces, asset
ownership, permissions, and the selected avatar remain on that profile.

This is a temporary development provider, not the final authentication system.
Firebase packages and their configuration remain installed for the normal
provider and other integration points; this does not remove every Firebase
dependency from the application.

## How it works

- The client uses `Net.get_auth_token()` for HTTP, WebSocket, and player join
  requests. Local mode requires `mirror/env_name="local"`, explicit opt-in,
  and loopback addresses for both backend transports.
- The backend accepts only a generated matching credential when
  `NODE_ENV=development` and `LUMINA_LOCAL_DEV_AUTH=true`. It maps that credential
  to one configured, existing user. No admin role or public unauthenticated
  endpoint is introduced. Standard REST/WebSocket role checks remain in place.
- The local native game host reads the same settings and validates the matching
  local credential before deriving the player identity. The credential is not
  passed as a host-process command-line argument.
- Profile loading has a 15-second timeout. A local connection failure exposes
  a retry button without email/password fields; it never silently creates a
  replacement profile.

Client-only machine settings in the ignored local environment config:
`local_dev_auth_enabled`, `local_dev_auth_token`, `local_dev_user_id` under
`[mirror]`. Backend-only machine settings in `.env`: `LUMINA_LOCAL_DEV_AUTH`,
`LUMINA_LOCAL_DEV_TOKEN`, `LUMINA_LOCAL_DEV_USER_ID`. Never publish the token.
The active `override.cfg` must match the local environment config. The existing
editor environment selector copies that file; it was refreshed during setup.

## Starting and verifying

The backend, MongoDB, and Redis still need to run. Starting only an unnamed
backend container without its port mappings is insufficient. Use the existing
`the_mirror_server`, `mongodb`, and `redis` containers. Keep the game at two CPUs
and below-normal priority as documented elsewhere. Only the user launches the
game; code preparation never starts gameplay automatically.

On the next user-started run, the client should reach Home without a sign-in
form. Then verify the existing Space opens, the avatar is retained, and a reload
works. Those live checks were not performed during installation.

Checks completed:

- Nine backend tests covering correct mapping, wrong/truncated credentials,
  missing configuration, disabled mode, and non-development rejection.
- Backend TypeScript production configuration passes `--noEmit` type checking.
- Isolated client tests exercise the actual Net provider methods, loopback
  restrictions, normal-provider fallback, and native player identity rejection.
- Actual HTTP profile/current-user/asset-list requests returned 201/200/200,
  preserving the existing profile ID and avatar selection.
- A WebSocket using the configured local identity remained connected.
- Headless editor checking reported no GDScript parse/compile errors; existing
  viewport/UID/OpenXR or engine startup/shutdown warnings remain.

## Reversing or replacing

Disable the client local flag and the backend local flag, refresh the local
environment override, restart the backend, and have the user restart the client
to return to the normal Firebase sign-in route. Existing Firebase auth caches
and login files were not deleted. Do not edit tokens or identity mappings just
to bypass an authorization failure.

Pre-change files and settings are backed up under ignored
`mirror-godot-app/.lumina-bridge/local-access-backups/20261101-113953`.
The `followup` subdirectory contains intermediate backups for native join
changes. No database documents were directly modified, no accounts were
recreated, and no world content was changed by installation.

The eventual authentication provider can replace this session-token boundary;
keep the backend user ID stable to preserve ownership and saved content.

## First user-run result

Automatic profile loading and local host authentication succeeded in the
November 1 trial. Space entry triggered the existing native physics guard.
See `docs/diagnostics/PHYSICS_FIRST_STEP_2026-11-01.md`: an uninitialized impulse
accumulator was corrected and the rebuilt engine passed a regression the old
binary failed. Reopen the editor before the next user-run validation. Space
entry/reload stability is not yet confirmed.

User confirmation: the next run after the native fix succeeded and the user resumed avatar testing in the Space. Repeat-entry validation remains pending.

## Two-player private-network extension

The user explicitly authorized configuring separate login identities for a LAN/
Tailscale test. See MULTIPLAYER_TEST.md and MULTIPLAYER_STATE.json. The original
owner mapping remains. A bounded development-only test-player registry and exact
private-host opt-in now support the guest. Earlier loopback-only descriptions
apply to the owner/default route; the guest explicitly targets 100.64.0.10.
Native host restart and the real second-PC test remain pending.
