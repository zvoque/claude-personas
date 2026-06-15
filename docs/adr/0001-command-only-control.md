# 1. Command-only control; hooks never parse prompts

Date: 2026-06-15
Status: Accepted

## Context

v1 (`claude-modes`) activated personas from natural language in the
`UserPromptSubmit` hook — `/contrarian`, `contrarian mode`, `stop contrarian`,
`normal mode`. Scanning every prompt for these triggers collides with ordinary
prose ("agent team", "back to normal", "the parallel approach") and with
Claude-native concepts. No reserved-word list can fence off English.

## Decision

The hooks do **no prompt parsing**. They only inject the active persona(s) from
state each turn. All control — activate, deactivate, switch operating mode,
create, delete, convene a team — goes through a single `/personas <arg>` command
(the proven `passive-adr` `/adr <subcommand>` pattern). `<arg>` is a verb if it
matches the reserved set (`list off solo parallel team new delete help on`),
otherwise a persona name to activate. State is mutated only by `personas-ctl.js`.

## Consequences

- **No false-positives, by construction** — nothing reads free text, so no prose
  or native-term clash can trigger anything. The reserved namespace shrinks to
  the command's own verbs.
- **Deletes the riskiest v1 code** — the trigger parser and false-positive guards
  (and the differential test burden) are gone.
- **Cost:** loses ergonomic `/contrarian` direct-slash and all natural-language
  activation. Everything is `/personas …`. A future reader expecting v1's NL
  triggers will find none — this ADR is why.
- **Cascade:** deactivation is uniform (`/personas off`), so persona bodies must
  not promise a per-persona off phrase, and `create-persona` does not ask for
  "off behavior".
- **One narrow exception to "no prompt parsing":** the hook recognizes its *own*
  `/personas` command prefix (exact leading match) to **suppress** self-injection
  on control turns — notably the `team` moderator turn, which must stay neutral.
  This is an exact-prefix check on the plugin's own command, not prose parsing,
  so it carries no collision risk and is consistent with this ADR.
