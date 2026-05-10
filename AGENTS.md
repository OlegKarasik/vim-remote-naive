# Agent Routing Index

This file is the entry point for routing and project concepts.

## Global Rules (always apply)

These rules govern AI-agent workflow in this repository and do not define or
constrain plugin runtime functionality.

1. DO NOT create or edit files outside of repository.
2. DO NOT redirect output from commands into files outside of repository.
3. DO NOT add or take dependencies on other plugins.
4. DO NOT introduce fallback behavior when a canonical interaction path is defined (for example, if popup UI is used, do not add a list/inputlist fallback).
5. In tests only, any single time-based wait/check interval must not exceed 90 seconds.
6. Every update to plugin functionality must be reflected to its wiki.
7. These global core rules override conflicting local core rules for AI-agent workflow.
8. Global asynchronous rules in `global-async-rules.txt` (umbrella root) are mandatory and override conflicting local async rules.

## Quick Project Surface

1. Commands: `RemoteConfig`, `RemoteSwitch`, `RemotePull`, `RemoteCancel`.
2. Core model: **Root Configuration** JSON file with `version`, `remotes`, and `current`.

## Documentation Index

1. `concepts.md` - critical concepts only.
2. `agents/core/rules.md` - non-negotiable global rules.
3. `agents/core/root-configuration.md` - Root Configuration location, schema, and lifecycle.
4. `agents/core/remotes.md` - remote object schema and active remote semantics.
5. `agents/commands/remote-commands.md` - command docs index.
6. `agents/commands/remote-config.md` - `:RemoteConfig` behavior and side effects.
7. `agents/commands/remote-switch.md` - `:RemoteSwitch` behavior and side effects.
8. `agents/commands/remote-pull.md` - `:RemotePull` behavior and side effects.
9. `agents/commands/remote-cancel.md` - `:RemoteCancel` behavior and side effects.
10. `agents/ui/popups-shared.md` - shared popup behavior notes.

## Lookup Guidance

1. Start here, then open `concepts.md`.
2. For configuration path/schema/lifecycle, open `agents/core/root-configuration.md`.
3. For remote fields and current marker behavior, open `agents/core/remotes.md`.
4. For command behavior, open `agents/commands/remote-commands.md`, then the specific command file.
