# Critical Concepts

1. **Single source of truth:** all persistent plugin state lives in **Root Configuration** (user-wide JSON file).
2. **State model:** `remotes` stores remote definitions; `current` stores the active remote.
3. **Remote shape:** every remote uses `connection`, `source`, and `destination` string fields.
4. **Command model:** `RemoteConfig` ensures and opens config, `RemoteAdd` appends remotes, `RemoteSwitch` picks and writes `current`.
5. **Selection behavior:** current remote is marked with `*`; cancellation keeps state unchanged.
6. **Detailed docs entry point:** start with `AGENTS.md`, then follow its index under `agents/`.
