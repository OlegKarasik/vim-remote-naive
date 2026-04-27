# RemoteAdd Command

**Scope:** `:RemoteAdd` behavior and side effects.
**Trigger keywords:** RemoteAdd, append remote, add connection.
**Depends on:** `agents/core/root-configuration.md`, `agents/core/remotes.md`.
**Conflicts:** none.

## Signature

`:RemoteAdd {connection} {local-path} {remote-path}`

## Behavior

1. Requires exactly three arguments.
2. Ensures Root Configuration exists before writing.
3. Appends one new remote object to `remotes` with mapping:
   - `connection` -> `connection`
   - `local-path` -> `destination`
   - `remote-path` -> `source`

## Guarantees

1. `current` is not changed.
2. The command does not open the Root Configuration buffer.
