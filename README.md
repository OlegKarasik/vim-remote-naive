# vim-remote-naive

> [!WARNING]
> This plugin was written by AI, except for `AGENTS.md`.

`vim-remote-naive` manages remote definitions in a user-wide JSON file and lets you switch the active remote inside Vim.

## Essentials

Available commands:

- `:RemoteConfig` - ensures the Root Configuration file exists and opens it.
- `:RemoteSwitch` - selects an entry from `remotes` and writes it to `current`.
- `:RemotePull` - pulls updates from the selected remote into the local destination using async `rsync` in a terminal.

Quick workflow:

1. Run `:RemoteConfig`.
2. Add remote entries to `remotes` in the opened JSON file.
3. Run `:RemoteSwitch` and choose the active remote.
4. Run `:RemotePull` to sync remote changes into your local directory.

## Detailed documentation (wiki format)

Detailed docs are split into wiki-style pages:

- [Wiki Home](wiki/Home.md)
- [Root Configuration](wiki/Root-Configuration.md)
- [Command Reference](wiki/Command-Reference.md)

Published wiki (GitHub): https://github.com/OlegKarasik/vim-remote-naive/wiki
