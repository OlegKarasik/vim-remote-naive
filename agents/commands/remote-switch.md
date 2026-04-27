# RemoteSwitch Command

**Scope:** `:RemoteSwitch` selection and current-remote updates.
**Trigger keywords:** RemoteSwitch, switch active remote.
**Depends on:** `agents/commands/remote-list.md`.
**Conflicts:** none.

## Signature

`:RemoteSwitch`

## Behavior

1. Uses the same selection flow as `:RemoteList`.
2. Shows the same remote list and `*` marker for current remote.
3. Updates `current` with the selected remote.
4. Cancelled selection keeps configuration unchanged.
