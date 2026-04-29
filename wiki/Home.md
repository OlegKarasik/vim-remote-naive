# Home

`vim-remote-naive` stores remote definitions in a user-wide Root Configuration JSON file and lets you select the active remote.

## Navigation

- [[Root-Configuration]]
- [[Command-Reference]]

## Quick workflow

1. Run `:RemoteConfig` to create/open Root Configuration.
2. Edit `remotes` in JSON.
3. Run `:RemoteSwitch` to set `current`.
4. Run `:RemotePull` to pull updates from remote to local with async `rsync`.
