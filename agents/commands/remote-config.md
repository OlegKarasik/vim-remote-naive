# RemoteConfig Command

**Scope:** `:RemoteConfig` behavior and side effects.
**Trigger keywords:** RemoteConfig, create config, open config buffer.
**Depends on:** `agents/core/root-configuration.md`.
**Conflicts:** none.

## Signature

`:RemoteConfig`

## Behavior

1. Resolves Root Configuration path for the current platform.
2. Ensures parent configuration directory exists.
3. Creates default Root Configuration content when the file is missing.
4. Opens Root Configuration in the current buffer (`:edit`).

## Guarantees

1. Existing configuration content is not overwritten.
2. Command always attempts to open the configuration file after ensure/create succeeds.
