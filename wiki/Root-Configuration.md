# Root Configuration

Root Configuration is the user-wide JSON file used by the plugin.

## Location by OS

- **Windows:** `%APPDATA%/vim-remote-naive/config.json` (fallback: `~/AppData/Roaming/vim-remote-naive/config.json`)
- **macOS:** `~/Library/Application Support/vim-remote-naive/config.json`
- **Linux:** `$XDG_CONFIG_HOME/vim-remote-naive/config.json` (fallback: `~/.config/vim-remote-naive/config.json`)

## Schema

- `version` (number)
- `remotes` (array of remote objects)
- `current` (optional remote object)

`current` is written by `:RemoteSwitch` and used by `:RemotePull`.

Remote object fields (strings):

- `connection`
- `source`
- `destination`

## Default content

```json
{
  "version": 1,
  "remotes": []
}
```

## Authoring remotes

Edit `remotes` directly in this file. Example:

```json
{
  "version": 1,
  "remotes": [
    {
      "connection": "ssh user@host-a",
      "source": "/srv/project-a",
      "destination": "/Users/me/project-a"
    },
    {
      "connection": "ssh user@host-b",
      "source": "/srv/project-b",
      "destination": "/Users/me/project-b"
    }
  ]
}
```
