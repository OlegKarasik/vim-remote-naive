# RemoteList Command

**Scope:** `:RemoteList` selection flow and update semantics.
**Trigger keywords:** RemoteList, choose remote, current marker, popup list.
**Depends on:** `agents/core/root-configuration.md`, `agents/core/remotes.md`, `agents/ui/popups-shared.md`.
**Conflicts:** none.

## Signature

`:RemoteList`

## Behavior

1. Reads and validates Root Configuration.
2. Requires a non-empty `remotes` array.
3. Builds selectable lines in format:
   `<marker><connection> | <source> -> <destination>`
4. Marks the currently active remote with `*`.
5. Shows popup selection (`popup_menu()`), or falls back to `inputlist()`.
6. Writes selected remote object to `current`.
7. Cancelled selection leaves configuration unchanged.
