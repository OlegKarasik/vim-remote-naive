# Remotes and Active Selection

**Scope:** Remote object semantics, field mapping, and active-remote behavior.
**Trigger keywords:** remote object, remotes array, current remote, active remote, selection marker.
**Depends on:** `agents/core/root-configuration.md`.
**Conflicts:** none.

## Remote object

1. Canonical fields (all strings):
   - `connection`
   - `source`
   - `destination`
2. The same shape is used in both `remotes[]` and `current`.

## Authoring remotes

1. Add and edit entries in `remotes` directly in Root Configuration JSON.

## Active remote (`current`)

1. `current` stores the selected remote object.
2. `:RemoteSwitch` updates `current` after user confirms selection.
3. `:RemotePull` uses `current` as source for rsync pull operation.
4. Cancelled selection leaves `current` unchanged.

## Selection line format

Rendered item format:

`<marker><connection> | <source> -> <destination>`

Marker values:

1. `* ` for the current remote
2. `  ` for a non-current remote
