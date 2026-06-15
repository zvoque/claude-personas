# Context — claude-personas

Glossary for the persistent-persona plugin. Terms only; no implementation detail.

## Core terms

- **Persona** — a *who*: a named character the agent adopts (e.g. `contrarian`). Stored as a plain data file `personas/<name>.md` (not a skill — ADR 0003). The entity, not the mechanism.
- **Mode** — *how* personas operate, not a persona itself. The operating mode is one of `solo` or `parallel`. ("Mode" is never the entity — that's a Persona.)
  - **solo** — exactly one persona active; activating another replaces it.
  - **parallel** — several personas active at once (capped), each answering in turn within one reply, not addressing each other.
- **Enabled set** — the personas currently active. Size 1 in solo, 2–3 in parallel.
- **Team** — an *on-demand action* (not a mode): convene enabled personas as a debating agent panel on a given topic, then synthesize and tear down.
- **Moderator** — the role that casts, runs rounds, and synthesizes a Team debate. Played by the main agent, not a separate persona.
- **Debater** — a persona cast into a Team panel for one debate. Derived from a Persona at convene-time; ephemeral.
