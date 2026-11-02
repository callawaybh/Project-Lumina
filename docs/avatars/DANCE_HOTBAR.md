# Dance action in hotbar slot 1

Implemented November 1, 2026 at the user's request. Slot 1 is a Dance action
using the downloaded Dancing Twerk.fbx. Press 1 or left-click the icon to toggle;
walk, jump, sit, die, aim, or enter VR to stop. Selecting another hotbar slot
also stops the dance. Holding 1, releasing a mouse button, typing into chat,
and using build-mode tool shortcuts do not toggle it. Programmatic hotbar
selection never starts a dance. The icon changes color while active.

Slot 1 is an action, not an equipment asset ID. Equipment cannot overwrite it;
clearing/loading the equipment hotbar preserves the action. An older first-slot
item moves to the next empty equipment slot. If the old hotbar is full, its
first item stays in saved data until a slot is available; no other item is
overwrittten by migration.

## Animation and networking

The animation is retargeted onto Mirror's canonical humanoid bind axes, using
66 tracks over 15.2 seconds at 30 fps. Hips keep vertical movement and local sway;
net horizontal travel is removed. The last 0.2 seconds blend to the first pose.
It is a separate AnimationTree branch with the existing 0.2-second stance blend.
Head-look overrides yield to the dance. Normal locomotion resumes on stopping.

Dance intent adds one boolean to the owning player's existing simulation input.
The authoritative/predicted active state and elapsed time are registered sync
variables. Remote snapshots carry active plus elapsed time, so another observer
or later joiner samples the same loop phase. No arbitrary animation names,
remote URLs, or unrestricted emote RPC were added. The input buffer size comparison
was corrected to call size(), and dance intent is included in count/comparison.

**Every client and the host must use this updated code** because the player input
and remote snapshot layouts changed. The engine does not need rebuilding.
The running game must be stopped and started again by the user to load the code.

## Verification and remaining live checks

- Initial live test FAILED: arms folded backward. The original offline preview and
  consistency checks missed the source T-pose versus target A-pose difference.
- Corrected source conversion plus per-avatar bind-pose adaptation: engine
  AnimationPlayer poses checked against the original FBX at six times on both
  the default and actual MPFB skeletons (228 torso/limb direction comparisons,
  below 0.1 degree tolerance). Three side-by-side previews reviewed.
- Each avatar receives a separate emote library; cached clip baking took about
  80 ms on this machine. Missing terminal-marker tracks are removed. Hips
  translation accounts for the engine motion_scale multiplication.
- Isolated native-engine suite: 444 checks passed for eligibility/cancellation,
  loop seam, actual DataBuffer input count/difference, production snapshot
  encode/decode with playback phase, matching observer/late-join graph poses,
  return to locomotion, mouse/key/chat/build-mode input, and equipment preservation.
- Full headless editor import/script scan: no script parse/compile errors.
- Existing engine shutdown resource-leak/dummy-shape warnings remain.
- The corrected live slot-1 dance, avatar appearance in motion, cancellation, and two actual
  connected players have not been confirmed yet. These remain user-run tests.

The isolated suite uses production hotbar/selection/serialization logic with
mock UI services and a minimal rig. It is not proof of an actual two-client
network session. Original locomotion clips are represented by stand-ins in
the isolated graph fixture; live locomotion transitions still need confirmation.

Runtime: mirror-godot-app/player/animations/dances/ and the hotbar/player/animation
controller changes. Conversion reference/scripts and the local Windows fixture
are retained under tools/lumina-avatar-tools/dance. From its regression directory,
run the installed Mirror engine with --headless --editor --import, followed by
--headless --quit-after 300. Fixtures reference this checkout at C:/Dev/LuminaClient.
The original FBX stays in the user's Downloads; Blender conversion uses two threads.

## Bind-pose correction following failed live test

The first converter aligned rotation axes but did not align the directions of
resting limbs. The Mixamo source has extended T-pose arms; Mirror's canonical
rig lowers them by about 60 degrees. The MPFB avatar also has different joint
positions despite matching canonical axes. Both stages now correct the rest
segment direction before transferring animated rotation. The loaded avatar gets
its own baked clip after model height/motion_scale setup; shared animation
libraries are never mutated. Locomotion and network payloads are unchanged by
this correction.

New reference: dances/dance_reference.gd. Runtime adaptation: dance_retarget.gd.
Source oracle: compare_and_preview.py reads native AnimationPlayer pose dumps,
compares source segment directions, and asserts before rendering previews.
The isolated dump forces skeleton transform updates to avoid reading cached
rest transforms. Previews are offline; live acceptance remains pending.

User confirmation: corrected dance works in the live single-player client. Minor shirt tearing was observed and explicitly deferred. Multiplayer remains unverified.
