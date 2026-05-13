# Command Reference

## `:RemoteConfig`

Ensures the Root Configuration file exists in the user-wide config directory and opens it in the current buffer.

Behavior:

1. Creates parent directory when needed.
2. Creates default configuration when missing.
3. Does not overwrite existing configuration.
4. Opens the configuration file in the current buffer.

## `:RemoteSwitch`

Reads `remotes` from Root Configuration and prompts for selection.

Behavior:

1. Requires existing, valid Root Configuration with non-empty `remotes`.
2. Requires a popup menu (`popup_menu()`); if popup support is unavailable,
   command reports an error and stops.
3. Marks the active remote with `*`.
4. Supports popup search mode (`Ctrl+F`) with filtering.
5. Writes selected remote object to `current`.
6. Keeps configuration unchanged when selection is cancelled.

## `:RemoteCancel`

Cancels the active async `:RemotePull` terminal job.

Behavior:

1. Stops the active RemotePull terminal job when one is running.
2. Reports `No active RemotePull job to cancel.` when nothing is running.
3. Restores temporary running-state UI (statusline progress) after cancellation.

## `:RemotePull`

Pulls updates from remote `source` into local `destination` for the currently selected remote (`current`) using `rsync` over SSH.

Behavior:

1. Reads and validates Root Configuration.
2. Requires `current` to be selected; otherwise errors and asks to run `:RemoteSwitch`.
3. Uses `rsync` over SSH to sync from remote to local:
   - remote: `<connection>:<source>/`
   - local: `<destination>/` (expands `~/...` to user home)
4. Rejects a new pull when another `:RemotePull` job is still active.
5. Starts `rsync` asynchronously in a terminal buffer.
6. While running, updates global statusline with command title and elapsed runtime.
7. On completion, restores statusline and reports `[Success]` or `[Error]` with elapsed runtime.
8. On failure, reports exit code when available.
9. Does not modify Root Configuration.
