# 2. Node for hooks and the control CLI (not bash, Python, or Rust)

Date: 2026-06-15
Status: Accepted

## Context

The plugin's executable parts — two hooks and a control CLI (`personas-ctl.js`) —
run on the user's machine with **no build step** (a marketplace plugin is just
files Claude Code clones). The binding constraint is *which runtime is
guaranteed to be present*, not performance or libraries. The workload is small:
read/write a JSON state file, read/write markdown persona files, validate names,
run a few regexes.

v1 shipped bash hooks; an earlier (now stale) decision favored bash-only.

## Decision

Use **Node.js** for both the hooks and the CLI.

- **Not bash:** guaranteed on macOS/Linux/WSL but **not** on native Windows
  (Git Bash optional), and JSON handling is painful. (See ADR rationale; v1's
  bash hooks were proven behavior-identical but dropped for Windows reach.)
- **Not Python:** `python3` is not guaranteed (no default user Python on macOS,
  frequently absent on Windows, not bundled by Claude Code) + version drift.
  Pairing a Python CLI with node hooks would require **two** runtimes and
  duplicate the shared resolution/validation logic.
- **Not Rust/compiled:** would require prebuilt per-platform binaries in the repo
  or a `cargo` toolchain on install — neither fits a clone-and-run plugin.
- **Node wins:** present wherever Claude Code was installed via npm (npm ships
  with Node); identical `node <file>` invocation on every OS incl. native
  Windows; `JSON` built in; zero dependencies; and the CLI shares
  `personas-lib.js` with the hooks — one runtime, one codebase.

## Consequences

- Single language across hooks + CLI; no duplicated logic, no second runtime.
- Dead only where `node` is truly absent (rare native-binary installs without
  Node) — hooks fail safe (no-op), never crash.
- Supersedes the stale dev-level "bash-only rewrite" ADR recorded earlier under
  the passive-adr store (that one should be `/adr supersede`-d).
