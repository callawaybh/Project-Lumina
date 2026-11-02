# Native runtime fixes

The game checkpoint uses Godot submodule revision
13b5ad644361de1675b368740e021ea4919a8f42 and network_synchronizer revision
9df9a53d875bc6687191c243bd35157061847308.

From a clean checkout with those submodules initialized, apply mirror-runtime.patch
with git apply from godot-engine, then apply network-synchronizer.patch from
godot-engine/modules/network_synchronizer. Build the custom Mirror engine normally.
These patches preserve singleton initialization order, scene synchronizer setup
and zero initialization of character impulses. Do not use a stock Godot binary.
Local working submodules were left intact; no upstream submodule branch was pushed.
