# vim-remote-naive

> [!WARNING]
> This plugin was written by AI, except for `AGENTS.md`.

`vim-remote-naive` currently provides three commands:

- `:RemoteConfig`
- `:RemoteAdd`
- `:RemoteSwitch`

## Root Configuration

**Root Configuration** is the user-wide JSON configuration file for this plugin.
The `:RemoteConfig` command creates this file when it does not already exist.

The main fields used by this plugin are:

- `remotes` (array): list of remote definitions.
- `current` (object): currently active remote selected by `:RemoteSwitch`.

Each item inside `remotes` is an object with string fields:

- `source`: source directory on the remote host.
- `destination`: destination directory on the local host.
- `connection`: connection value used to access the remote host.

## `:RemoteConfig`

Ensures the default **Root Configuration** JSON file exists in the user-wide config directory and opens it in the current buffer.

Location by OS:

- **Windows:** `%APPDATA%/vim-remote-naive/config.json` (fallback: `~/AppData/Roaming/vim-remote-naive/config.json`)
- **macOS:** `~/Library/Application Support/vim-remote-naive/config.json`
- **Linux:** `$XDG_CONFIG_HOME/vim-remote-naive/config.json` (fallback: `~/.config/vim-remote-naive/config.json`)

If the Root Configuration file already exists, the command leaves it unchanged and opens it.

Default file content:

```json
{
  "version": 1,
  "remotes": []
}
```

## `:RemoteSwitch`

Reads Root Configuration field `remotes` and shows a selection popup (or an input-list fallback when popup support is unavailable).

The current remote is marked with `*`. After selecting a remote, the selected object is written to Root Configuration field `current`.

If selection is cancelled, Root Configuration is not changed.

## `:RemoteAdd`

Appends a new remote object to Root Configuration field `remotes`.
If Root Configuration does not exist yet, `:RemoteAdd` creates the default file first.

Usage:

```vim
:RemoteAdd {connection} {local-path} {remote-path}
```

Field mapping:

- `connection` -> `connection`
- `local-path` -> `destination`
- `remote-path` -> `source`
