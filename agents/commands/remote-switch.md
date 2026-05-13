# RemoteSwitch Command

**Scope:** `:RemoteSwitch` selection and current-remote updates.
**Trigger keywords:** RemoteSwitch, switch active remote.
**Depends on:** `agents/core/root-configuration.md`, `agents/core/remotes.md`, `agents/ui/popups-shared.md`.
**Conflicts:** none.

## Signature

`:RemoteSwitch`

## Behavior

1. Reads and validates Root Configuration.
2. Requires a non-empty `remotes` array.
3. Requires a remote selection popup (`popup_menu()`); if popup support is
   unavailable, command reports an error and stops.
4. Shows `*` marker for the current remote.
5. Supports popup search mode (`Ctrl+F`) and query filtering.
6. Updates `current` with the selected remote.
7. Cancelled selection keeps configuration unchanged.
