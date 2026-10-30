# Lumina local builder bridge

Developer-only JSON command API for the running **Mirror client**, rather than the
Godot editor scene. No MCP plugin is required for Codex to call the CLI.
This is a local file-based bridge, not an installed MCP server or HTTP endpoint.

Installation: copy `lumina_bridge.gd` to `mirror-godot-app/scripts/autoload/`, add
`LuminaBridge="*res://scripts/autoload/lumina_bridge.gd"` under `[autoload]` in
`project.godot`, and ignore `.lumina-bridge/` in the project's `.gitignore`.
The implementation is installed in the development checkout by this task.

Enable with `py -3.12 bridge.py enable`, then restart the game and join a local
Space. The bridge only processes requests in an editor-capable engine binary,
with the `local` environment and the enable marker present; host processes do not
process requests. Writes additionally require edit mode and contributor rights.
Disable with `py -3.12 bridge.py disable`. Keep one development client running.

Examples (run beside this file):

```powershell
py -3.12 bridge.py status
py -3.12 bridge.py join_space SPACE_ID
py -3.12 bridge.py list_objects
py -3.12 bridge.py create_primitive --name "Bridge Red Box" --shape box --position 3 0 -3 --size 1 1 1 --color 1 0 0 1
py -3.12 bridge.py update_object OBJECT_ID --position 4 0 -3
py -3.12 bridge.py rename_object OBJECT_ID "Wall Panel 01"
py -3.12 bridge.py duplicate_object OBJECT_ID --name "Wall Panel 02" --offset 2 0 0
py -3.12 bridge.py create_group "Wall Module" OBJECT_ID_1 OBJECT_ID_2
py -3.12 bridge.py list_groups
py -3.12 bridge.py rename_group GROUP_ID "North Wall Module"
py -3.12 bridge.py move_group GROUP_ID --offset 0 0 -5
py -3.12 bridge.py duplicate_group GROUP_ID "South Wall Module" --offset 0 0 10
```

Coordinates are world meters; creation uses **bottom center** position. Sphere
diameter uses size X; cylinder diameter uses X and height uses Y. Rotation updates
are radians. Color is RGBA in [0,1]. Recoloring supports bridge-created primitives
only and exports a replacement colored model asset: this Mirror revision does not
render the legacy `objectColor` field. The bridge's ignored request history is
needed to recover the primitive geometry for recoloring. Existing assets are kept.
Update positions refer to the existing model's origin.

Creation follows ModelRoot's native GLB export, AssetBrowser upload, and Zone
network spawn, waiting up to 30 seconds for the receipt acknowledgement. The
server remains responsible for permissions and database persistence. Updates use
the native Zone update packet and local delta application. Updates now poll the
permission-checked object API for matching database values before returning
`state: saved`. If verification fails, the update may still have been applied;
inspect before retrying. Upload failures can leave unused assets; no automatic
deletion occurs.

## Naming, duplication, and groups

Object names are persisted on world objects; renaming does not rename shared
assets. Names must contain 1 to 80 characters and no control characters. New
primitive objects now keep the supplied name. Mirror may append a suffix when
creating a copy if another object already has the requested name.

Duplication uses Mirror's normal asset-backed spawn with a unique receipt. It
reuses the source's current model asset, transform, model offset, material,
physics, audio, extra node, and script properties where supported by the native
creation API. New document IDs and ownership are assigned by Mirror. It does not
copy database identity, roles, or parent links. Source geometry is not rebuilt.
Copying a bridge primitive also preserves its local recoloring recipe.

Groups are **named bridge collections**, not native Godot parent nodes or folders
in Mirror's Entities panel. Members remain independent world objects. Group names
are unique within a Space, and a group contains 1 to 100 unique editable objects.
Membership is saved as a JSON string under
`Space.customData.data.luminaBuilderGroups`, through the existing authenticated
Space API; it is included in the MongoDB backup, not just local command history.
No backend schema or authentication bypass is added. Metadata writes require
whatever permissions the native Space API requires (normally the Space owner or
manager). Work with one bridge client at a time: metadata uses read-modify-write.

`move_group` translates every member by the supplied world-space offset, keeping
their spacing. `duplicate_group` copies all members and saves a new independent
named group. Whole-group rotation/scaling, nested groups, and membership editing
are not exposed in this version. Members may overlap between groups; a copy is
not automatically added to any of the source object's other groups.

Group commands preflight all members and destinations. Multiple-object changes
are not a database transaction: a network failure can leave a partial result.
The response lists completed operations and the failed member, or reports that
copies exist but metadata saving failed. Inspect that result rather than blindly
retrying. There is no automatic deletion or rollback. If members have been
removed outside the bridge, group editing refuses to proceed until repaired.

Requests are unique JSON files, atomically published and claimed before execution.
Responses are atomic JSON files. Claimed commands are never automatically replayed.
If a command times out after claim, inspect current objects before retrying; a
create may already have succeeded. A timeout before claim cancels the request.
The inbox includes execution history and is ignored by Git. No passwords, auth
tokens, arbitrary scripts, delete commands, or external network listeners are exposed.
Any local process that can write the inbox can invoke its supported commands.

## Validation performed

- Godot project/editor scan: no bridge parse or compile errors.
- Seven Python checks pass (protocol behavior and naming/group/duplicate command construction), using Python 3.12.
- Live status, list, join, and invalid-command rejection checked.
- Created one Bridge Test Box through native GLB upload and network spawn.
- Moved it to [-2, 0, -4] and recolored it red by replacing its model asset.
- Confirmed the object and replacement asset in MongoDB; GLB material contains red RGBA.
- Restarted the client and rejoined: object remains at its saved location and visibly red.
- Extension live checks: renamed the original test box, duplicated it with the same model asset, saved a two-member group, moved both members, duplicated the group, and renamed the copied group.
- Invalid group membership was rejected before saving metadata.
- Restarted the extended client and rejoined: both named groups, their four member IDs, object names, shared red model asset, and saved positions were restored. Three new test copies remain alongside the original bridge box in `luminara1`.

See CHECKPOINT.md for the validated scope and remaining runtime issues.
