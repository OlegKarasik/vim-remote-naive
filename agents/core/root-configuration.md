# Root Configuration

**Scope:** User-wide configuration file location, schema, lifecycle, and validation.
**Trigger keywords:** root configuration, config path, config schema, version, remotes, current.
**Depends on:** `agents/core/rules.md`.
**Conflicts:** none.

## Location

1. Windows: `%APPDATA%/vim-remote-naive/config.json` (fallback: `~/AppData/Roaming/vim-remote-naive/config.json`)
2. macOS: `~/Library/Application Support/vim-remote-naive/config.json`
3. Linux: `$XDG_CONFIG_HOME/vim-remote-naive/config.json` (fallback: `~/.config/vim-remote-naive/config.json`)

## Schema

1. Root object fields:
   - `version` (number)
   - `remotes` (array)
   - `current` (optional object)
2. `remotes` entries and `current` use the same remote object shape:
   - `connection` (string)
   - `source` (string)
   - `destination` (string)

## Default payload

```json
{
  "version": 1,
  "remotes": []
}
```

## Lifecycle

1. `:RemoteConfig` ensures the file exists and opens it in the current buffer.
2. `remotes` entries are authored directly in Root Configuration.
3. `:RemoteSwitch` reads and updates `current`, but does not create config automatically.
4. `:RemotePull` reads `current` and pulls updates into local destination, but does not modify config.

## Validation on read

1. File must exist and be valid JSON.
2. Root JSON value must be an object.
3. `remotes` must exist and be an array.
4. Each remote entry must contain string `connection`, `source`, and `destination`.
