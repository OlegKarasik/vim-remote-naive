# vim-remote-naive

> [!WARNING]
> This plugin was written by AI, except for `AGENTS.md`.

`vim-remote-naive` currently provides two commands:

- `:RemoteConfig`
- `:RemoteList`

## Root Configuration

**Root Configuration** is the user-wide JSON configuration file for this plugin.
The `:RemoteConfig` command creates this file when it does not already exist.

The main fields used by this plugin are:

- `remotes` (array): list of remote definitions.
- `current` (object): currently active remote selected by `:RemoteList`.

Each item inside `remotes` is an object with string fields:

- `source`: source directory on the remote host.
- `destination`: destination directory on the local host.
- `connection`: connection value used to access the remote host.

## `:RemoteConfig`

Creates the default **Root Configuration** JSON file in the user-wide config directory.

Location by OS:

- **Windows:** `%APPDATA%/vim-remote-naive/config.json` (fallback: `~/AppData/Roaming/vim-remote-naive/config.json`)
- **macOS:** `~/Library/Application Support/vim-remote-naive/config.json`
- **Linux:** `$XDG_CONFIG_HOME/vim-remote-naive/config.json` (fallback: `~/.config/vim-remote-naive/config.json`)

If the Root Configuration file already exists, the command leaves it unchanged.

Default file content:

```json
{
  "version": 1,
  "remotes": []
}
```

## `:RemoteList`

Reads Root Configuration field `remotes` and shows a selection popup (or an input-list fallback when popup support is unavailable).

After selecting a remote, the selected remote object is written to Root Configuration field `current`.

If selection is cancelled, Root Configuration is not changed.
