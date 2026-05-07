# RemoteCancel Command

**Scope:** `:RemoteCancel` cancellation of active pull jobs.
**Trigger keywords:** RemoteCancel, cancel pull, stop async pull.
**Depends on:** `agents/commands/remote-pull.md`.
**Conflicts:** none.

## Signature

`:RemoteCancel`

## Behavior

1. Stops the active `:RemotePull` terminal job when one is running.
2. Reports `No active RemotePull job to cancel.` when there is nothing to stop.
3. Restores temporary running-state UI (statusline progress) after cancellation.
4. Completion reporting follows async lifecycle rules (`[Error]` with elapsed
   runtime and exit code for canceled/failed jobs).
