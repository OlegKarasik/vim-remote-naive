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
2. Shows a popup menu (`popup_menu()`) when available, otherwise uses `inputlist()`.
3. Marks the active remote with `*`.
4. Supports popup search mode (`Ctrl+F`) with filtering.
5. Writes selected remote object to `current`.
6. Keeps configuration unchanged when selection is cancelled.

## `:RemotePull`

Pulls updates from remote `source` into local `destination` for the currently selected remote (`current`) using `rsync` over SSH.

Behavior:

1. Reads and validates Root Configuration.
2. Requires `current` to be selected; otherwise errors and asks to run `:RemoteSwitch`.
3. Uses `rsync` over SSH to sync from remote to local:
   - remote: `<connection>:<source>/`
   - local: `<destination>/`
4. Starts `rsync` asynchronously in a terminal buffer.
5. Does not modify Root Configuration.
