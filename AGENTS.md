# Agent Routing Index

This repository currently implements two commands (`RemoteConfig`, `RemoteList`) and one core concept: **Root Configuration** (the user-wide JSON config file with `remotes` and `current` fields).

## Global Rules (always apply)

1. DO NOT create or edit files outside of repository.
2. DO NOT redirect output from commands into files outside of repository.
3. DO NOT take dependencies on other plugins.
4. When waiting for command output, never wait longer than 90 seconds per check.

## Lookup Guidance

1. Work directly with files present in this repository.
2. There are no command-routing documents at this time.
