# RemotePull Command

**Scope:** `:RemotePull` rsync pull behavior and side effects.
**Trigger keywords:** RemotePull, rsync pull, pull remote updates.
**Depends on:** `agents/core/root-configuration.md`, `agents/core/remotes.md`.
**Conflicts:** none.

## Signature

`:RemotePull`

## Behavior

1. Reads and validates Root Configuration.
2. Requires a selected `current` remote object.
3. Fails with guidance to run `:RemoteSwitch` when `current` is missing or invalid.
4. Builds an rsync pull command using SSH transport from current remote:
   - remote source: `<connection>:<source>/`
   - local destination: `<destination>/`
5. Starts rsync asynchronously in a terminal buffer.

## Guarantees

1. Root Configuration content is never modified by this command.
2. Command runs asynchronously and returns control to Vim immediately.
