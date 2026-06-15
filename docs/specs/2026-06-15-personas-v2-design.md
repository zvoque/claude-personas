# claude-personas v2 — Design Spec

Date: 2026-06-15
Status: Approved for planning

## 1. What this is

`claude-personas` is a Claude Code marketplace plugin for **persistent persona modes** — personas (a sharp `contrarian`, a `hype-man`, a `security-hawk`, …) that re-assert themselves on *every* turn until switched off, which a plain skill cannot do. It also lets users **author their own personas** through a guided interview, and **convene their personas as a debating agent team** on demand.

It supersedes the v1 `claude-modes` plugin: same core hook mechanism, renamed vocabulary, node runtime, and three new capabilities (parallel personas, a persona creator, an on-demand team).

### Vocabulary (deliberate)
- **persona** = the *thing* (who). Stored as a data file `personas/<name>.md` (not a skill — ADR 0003).
- **mode** = how personas *operate*: `solo` or `parallel` (the ambient operating mode). Retained on purpose — "mode" describes the operating state, not the entity.
- **team** = an on-demand *action*, not an operating mode.

## 2. Goals / Non-goals

**Goals**
- Work on every Claude Code install (node runtime — guaranteed wherever CC's npm install put node; cross-platform incl. Windows).
- Singleton by default; opt-in parallel personas.
- User-authored personas via a guided (`AskUserQuestion`) interview.
- On-demand multi-agent debate among the user's personas, self-contained (no second plugin install).
- Never block a prompt or session start (hooks fail safe, exit 0).

**Non-goals (YAGNI)**
- Persistent/auto-saved "team-only" personas — cut. Gap-fillers are cast fresh per debate (topic-tuned) and discarded; a keeper is promoted to a real persona via the creator.
- A separate coordinator *agent* — the main model moderates.
- Stored debater briefs — debaters are derived from personas at convene-time.
- Team as an ambient (every-turn) mode — it is on-demand only.
- Cross-persona pairwise interaction matrices — parallel uses a single non-interactive framing.

## 3. Data model

A **persona** is a plain markdown **data file** `<name>.md` — **not** a skill (ADR 0003). It is never surfaced to Claude as an invokable skill; only the hook, the CLI, and the `team` skill read it.

```markdown
---
name: contrarian
description: <one-line who/what — shown in `/personas list`>
---
<persona instructions — addressed to Claude>
```

Personas resolve from **both** (personal **overrides** bundled on name collision):
1. `${CLAUDE_PLUGIN_ROOT}/personas/` — personas shipped with the plugin.
2. `~/.claude/personas/` — personas the user authors.

**Name rule:** `^[a-z0-9][a-z0-9-]*$` (path-traversal guard; also must not be a reserved verb — Section 8).

**Persona ↔ debater:** every persona is automatically team-eligible. The team skill derives a debater brief (identity / motive / fear / voice / stance) from the persona body at convene-time. No separate artifact, no extra authoring step.

## 4. State

Persistent operating state lives at `~/.claude/.personas-active` as JSON:

```json
{ "mode": "solo", "enabled": ["contrarian"] }
```

- `mode`: `"solo"` (default) or `"parallel"`.
- `enabled`: ordered list of active persona names (most-recent last).

**Migration:** if `.personas-active` is absent but the legacy `~/.claude/.modes-active` exists (a bare persona name), read it as `{ "mode": "solo", "enabled": ["<name>"] }` and write the new file. Tolerate a malformed/legacy bare-string `.personas-active` the same way.

All state I/O is defensive: unreadable/invalid → treated as "no personas active".

**Sole writer.** Every filesystem side effect — the state JSON **and** persona data files (`personas/<name>.md`) — goes through **`personas-ctl.js`** (a small node CLI sharing `personas-lib.js`: `enable|disable|parallel|solo|list|create|delete`). The `/personas` command invokes it via Bash; `create-persona` calls its `create`. The hooks are **readers only** — they inject state, never mutate it (ADR 0001). The LLM never hand-writes the state JSON or persona files (no non-atomic/malformed/race writes; deterministic and unit-testable). Note: when `/personas` changes state, the `UserPromptSubmit` hook for that same prompt has already run, so the change applies to the *next* turn's injection (documented quirk).

**Self-healing & deletion.** `delete` removes the persona file **and** prunes its name from `enabled` (cascade). When injecting, the hook **silently skips** any enabled name that no longer resolves; the CLI prunes dead names on its next write. Deleting a personal persona that shadows a bundled one **warns** that the bundled one is now active; deleting a name that exists **only** as bundled is **refused** (disable it or make a personal override — bundled files are read-only plugin content).

**Scope & concurrency.** State is **global** (`~/.claude/.personas-active`): a persona is active across all projects and sessions — it is user-level identity, not per-project config (matches v1). Writes are atomic (tmp + rename); two concurrent sessions are last-write-wins, which is rare and low-stakes. Per-project scoping is a possible future option, not MVP.

## 5. Layer 1 — persistent personas (node hooks)

Hooks wired via `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}`, run with node.

| Event | Hook | Behavior |
|---|---|---|
| `UserPromptSubmit` | `personas-tracker.js` | **Inject-only** — read state, inject the active persona(s) each turn (a **short re-assertion**; the full body comes from the session-event hook — §15). **No prompt parsing**; **skips injection on `/personas` command turns**. |
| `SessionStart` / `PreCompact` | `personas-activate.js` | Inject the **full** persona(s) on start / resume / clear / before-compaction, re-establishing them after any context reset (§15). |
| shared | `personas-lib.js` | State JSON I/O, name validation, persona resolution (dual-dir), frontmatter-stripped persona reading, JSON-escaped context emission. |

**solo (default).** `enabled` holds at most one. Activating a persona **replaces** the list. Inject it each turn (full on the session-event hook, a short re-assertion otherwise — §15).

**parallel (opt-in).** Activating **appends**. **No hard cap** (user autonomy) — but past ~4 the command warns that replies grow long (each persona answers in turn) and full re-injection on session events scales per persona (§15), then proceeds if the user confirms. Each turn, inject all enabled personas, each clearly delimited, prefixed with a single framing instruction:

> Multiple personas are active. Respond as each in turn, clearly labeled, in one message. Personas do not address one another.

This is non-interactive and bundled into one reply (no inter-persona dialogue — that is what `team` is for).

**Switching `mode`** (via `/personas parallel` / `/personas solo`):
- → `parallel`: subsequent activations append (unbounded; soft-warned past ~4).
- → `solo`: `enabled` collapses to the most-recently-activated persona.

**Control is the `/personas` command (Section 8) — the hooks never parse prompts for control.** This eliminates, by construction, prose collisions ("agent team", "back to normal", "the parallel approach") and Claude-native-term clashes — nothing scans free text. Activation, deactivation, and mode switches all route through `/personas <…>` → `personas-ctl.js`. (This deletes v1's entire trigger-parser/false-positive-guard machinery.)

**One narrow prompt check — self-suppression.** The `UserPromptSubmit` hook **skips injection** when the prompt is one of the plugin's own `/personas …` commands (exact leading `^/personas\b` match). So control turns — and the `team` moderator turn especially (Section 7) — are never persona-flavored. This is an exact match on the plugin's *own* command prefix, **not** prose parsing, so it carries no collision risk (nobody types `/personas team` as prose) and preserves ADR 0001's spirit. Whether a registered slash command's text actually reaches the hook is undocumented in Claude Code; **validate at build time** — if the text reaches the hook the skip fires; if registered commands bypass the hook entirely, the turn is clean anyway. (`disableAllHooks` is global-only; there is no per-turn hook-disable API.)

Errors are swallowed; hooks always exit 0. `PERSONAS_DEBUG=1` logs decisions to `~/.claude/.personas-debug.log`.

## 6. Layer 2 — persona creator (`create-persona` skill)

A skill (not a hook — hooks are non-interactive). Triggered by `/personas new`.

Conducts a guided interview with `AskUserQuestion`, one decision at a time:
1. **Name** (validated; rejected if it collides with an existing persona or a reserved verb — Section 8).
2. **Description / when it applies** — feeds the skill frontmatter `description` (so Claude can also auto-offer it).
3. **Role** — what it does / what it pressure-tests / its job.
4. **Voice** — tone and speaking style.
5. **When it steps aside** — auto-clarity exceptions (destructive actions, explicit clarify requests).

Deactivation is **not** asked: off is uniform (`/personas off`), so persona bodies must never promise a per-persona off phrase (the hook would re-inject regardless — a lie). The interview only **gathers inputs**, then calls **`personas-ctl.js create`** to write `~/.claude/personas/<name>.md` — the CLI does name + reserved-verb validation, collision handling, valid frontmatter, and an atomic write (the LLM never hand-writes the file). The body is assembled from the answers, written as instructions to Claude and rich enough to derive a debater brief from. Confirms the path and how to activate (`/personas <name>`).

**Body via stdin.** The assembled body is piped into `personas-ctl.js create` on **stdin** (never a shell arg), so a multi-paragraph body needs no escaping. **No edit command (MVP):** to change a persona, edit `~/.claude/personas/<name>.md` directly, or `delete` + `new`. A pre-filled `/personas edit` can come later if hand-editing proves annoying.

## 7. Layer 3 — team (`team` skill, vendored from debate-team)

On-demand only. Invoked by `/personas team [topic]`. (The hook never triggers it; it is a deliberate command action.)

- **Roster** is chosen at convene-time, **independent of ambient state**: `AskUserQuestion` lists **all** personas with the currently-enabled ones pre-checked as the default; the user adds/removes. Each chosen persona is cast into a debater brief derived at convene-time. Team is **fully orthogonal** to the ambient hook: a debate modifies **neither** the enabled-set **nor** the operating mode (no auto-parallel), spawns isolated debater agents, and never touches what the hook injects. One-shot in, clean exit.
- **Gap-fill:** the same step offers to auto-cast additional debaters to fill missing angles (debate-team's casting). Added debaters are **ephemeral** — used for this debate, then discarded. (To keep one, the user promotes it via `create-persona`.)
- **Cast transform (not copy):** each chosen persona is reshaped into a debater brief (`IDENTITY / CORE MOTIVE / WHAT YOU FEAR / VOICE / STANCE`). The moderator extracts only the *character* and **discards mode-mechanics** — persistence clauses, off behavior, auto-clarity exceptions, output-format scaffolds, cross-persona interaction notes — so a debater never tries to "persist every turn" or emit its ambient output format mid-debate.
- **Friction check (before spawning):** the moderator judges whether the roster has genuinely *opposed* incentives — debate-team's #1 failure is a flat roster. If personas are stylistic (e.g. a terse-output persona with no stance) or mutually aligned, it **warns and offers to add an opposing auto-cast debater or drop non-debaters** before convening. Flatness *triggers* the gap-fill, not just missing angles.
- **Snapshot semantics:** spawned debaters are **isolated** from the ambient persona hooks (a debater agent does not also receive the hook injection). A debate persona is therefore a *derived snapshot*, not the user's live persona, and may argue somewhat differently. Stated to the user at convene-time.
- **Moderator neutrality (deterministic, not an override):** the moderator is the **main session** — forced, because only a team *lead* can orchestrate a team (subagents cannot). Neutrality is kept by the hook **skipping injection on the `/personas team` turn** (Section 5), so no active persona contaminates casting / rounds / synthesis — no "disregard the persona" prompt-injection hack. **Fallback** (if a build-time test shows the hook still injects on command turns): produce the **synthesis in a clean subagent** that receives only the transcript — the verdict is the bias-sensitive part, and subagents don't inherit the persona hook.
- **Minimum roster:** a debate needs **≥2 debaters**; if fewer are selected, gap-fill is required, otherwise the debate aborts with a message.
- **Teardown / orphans:** the skill shuts members down + `TeamDelete`s even if cut short; a **hard-killed** turn can still orphan agents — documented with manual-cleanup guidance, since no skill can guarantee cleanup against a force-terminated turn.
- **Confirmation:** the same preview confirms the full roster and flags cost (N agents) before spawning.
- **Coordinator:** the main model moderates (casts, runs rounds, synthesizes, tears down) following debate-team's moderator rubric. No separate coordinator agent.
- **Execution:** real agents via `TeamCreate` / `Agent` / `SendMessage`; **falls back** to single-context sequential role-play where multi-agent primitives are unavailable.
- **Output:** transcript + synthesis (key tensions, convergence, steelman per side, what it depends on, verdict, open questions).
- **Teardown:** `SendMessage` shutdown + `TeamDelete`, always, even if cut short.

Vendored whole: `skills/team/SKILL.md` (adapted from `debate-team`, wired to read enabled personas as the roster) + `skills/team/references/casting-library.md` (copied verbatim). One canonical copy lives here; the skills-repo copy is unaffected for now.

## 8. Control surface — `/personas` command

A single `commands/personas.md` (passive-adr's `/adr <subcommand>` pattern). The first arg is a **verb** if it matches the reserved set, otherwise a **persona name to activate**:

| Invocation | Effect |
|---|---|
| `/personas` or `/personas list` | Show all personas, which are enabled, and the operating mode. |
| `/personas <name>` | Activate `<name>` (solo replaces; parallel appends to the cap). |
| `/personas off [name]` | Deactivate one persona, or all if no name. |
| `/personas solo` / `/personas parallel` | Set operating mode. |
| `/personas team [topic]` | Convene the team debate (Layer 3). |
| `/personas new` | Invoke `create-persona`. |
| `/personas delete <name>` | Remove a user-authored persona (never bundled; confirms first). |

**Reserved verbs** (a persona may not be named one of these): `list off solo parallel team new delete help on`. Enforced at creation by `create-persona` / `personas-ctl.js`. This is the *entire* reserved namespace — no English-wordlist guessing, because the hook no longer parses prose.

All mutations go through `personas-ctl.js` (Section 4); the command is a thin dispatcher over it.

## 9. File layout

```
claude-personas/
  .claude-plugin/marketplace.json          # name: claude-personas; plugin: personas
  plugins/personas/
    .claude-plugin/plugin.json             # name: personas
    commands/personas.md                   # control surface
    hooks/hooks.json                        # node personas-tracker / personas-activate
    hooks/personas-lib.js
    hooks/personas-tracker.js
    hooks/personas-activate.js
    hooks/personas-ctl.js                  # CLI: sole writer of state + persona files
    personas/contrarian.md                 # bundled persona DATA (not a skill)
    skills/create-persona/SKILL.md         # Layer 2 (real skill)
    skills/team/SKILL.md                   # Layer 3 (vendored debate-team)
    skills/team/references/casting-library.md
  tests/                                    # node-driven; sandbox HOME
  docs/specs/2026-06-15-personas-v2-design.md
  README.md  LICENSE  .gitignore
```

Install: `/plugin marketplace add zvoque/claude-personas` → `/plugin install personas@claude-personas`.

## 10. v1 → v2 (clean reinstall — no migration)

v1 (`claude-modes`) was **never published** — the only install anywhere is the author's local one. So there is **no migration to build**; v2 is effectively the first release.

- **Clean reinstall.** The author removes v1 by hand (the two hook entries in `~/.claude/settings.json` and the `~/.claude/hooks/modes-*.js` files), then installs v2. v2 uses its own state file `.personas-active` and ignores the stale `.modes-active` (delete it if you like).
- **No automated migration, no v1 detection, no marker back-compat, no sentinel** — all dead weight for a one-user clean cut.
- **Active state does not carry across the cut** — re-activate after reinstall (`/personas contrarian`).
- **Principle retained:** v2 never edits `settings.json` or any user file itself; the v1 removal is the user's manual step.

## 11. Runtime decision

Node (`.js`, CommonJS), invoked `node "${CLAUDE_PLUGIN_ROOT}/hooks/<x>.js"`. Rationale: node is present wherever CC was installed via npm and is invoked identically on every OS (incl. native Windows, where bash is not guaranteed). The v1 bash hooks were proven behavior-identical to the node version via differential testing; node is the chosen single runtime. Bash hooks retired.

## 12. Testing

- **`personas-ctl.js` unit tests (the deterministic core):** `enable`/`disable`/`solo`/`parallel` transitions; `create` (valid frontmatter, name + reserved-verb rejection, collision handling, atomic write); `delete` (personal-only; bundled-protected; confirms; cascades removal from state); dual-dir persona resolution with personal **overriding** bundled; path-traversal rejection.
- **Hook tests (inject-only):** given a state file, the hook injects the right persona body (frontmatter stripped, JSON-escaped), solo vs parallel framing + ordering, SessionStart injection, and fail-safe (no output, exit 0) on malformed/missing state. No trigger-parsing tests — the hook no longer parses prompts (ADR 0001).
- **Manual smoke checklist** (`tests/SMOKE.md`) for the irreducibly-LLM skills: `/personas new` → a valid persona file is written and activates; `/personas team <topic>` → roster preview, friction check, synthesis, teardown. Honest manual checks, not faked unit tests.
- Sandbox `HOME`; real `~/.claude` never touched. `tests/run.sh` aggregates the node tests.

## 13. Phases (each ships independently)

1. **Core** — node hooks; `persona`/`mode`/state rename; solo + parallel (cap); dual-dir resolution; `/personas` control surface; v1 migration. Replaces the current bash plugin.
2. **create-persona** — guided `AskUserQuestion` interview → personal persona data file (`~/.claude/personas/<name>.md`).
3. **team** — vendor debate-team; roster from enabled personas (derived debaters); ephemeral gap-fill; moderator rubric; transcript + synthesis.

## 14. Open risks

- **Parallel contamination / token tax** — multiple personas in one context blur and cost linearly per turn. No hard cap (user autonomy); mitigated by a soft warning past ~4 and the non-interactive framing. A deliberate, informed user trade.
- **Team in non-multi-agent environments** — degrades to sequential role-play (less rich, still useful); flagged to the user at convene-time.
- **Vendoring drift** — `debate-team` now exists in two repos; `claude-personas` is canonical going forward.

## 15. Token efficiency

Re-injecting the full persona every turn is the cost driver (solo ≈ one persona body/turn; parallel ×N). Design to minimise it without weakening the persona:

- **Full** persona injected on `SessionStart` **and `PreCompact`** — re-establishes the persona after any context reset or compaction.
- **Short re-assertion** on each `UserPromptSubmit` ("Hold the `<name>` persona established above; keep its structure.") instead of the full body. The full text remains upthread; a cheap pointer keeps it salient. Parallel benefits most — N× short, not N× full.
- **No injection on `/personas` command turns** (Section 5).
- **Brevity** — `create-persona` nudges concise bodies.
- **Visible tax** — the hook logs a per-turn token estimate to `~/.claude/.personas-inject.log`.
- **Risk + fallback:** the short pointer assumes the full text is still in context (true except across compaction, covered by `PreCompact`/`SessionStart`). Validate long-session sharpness at build time; if the persona drifts, fall back to full-per-turn (or full every Nth turn). Hook adds `PreCompact` to its events for this.

## 16. Coexistence with other persona/lifecycle plugins (caveman, ponytail)

caveman and ponytail are popular persona-injecting lifecycle-hook plugins users will run alongside this one. Confirmed: caveman uses flag `.caveman-active`, `SessionStart`+`UserPromptSubmit` hooks, `/caveman*` commands; ponytail ships two lifecycle hooks and `/ponytail*` commands.

**Mechanical isolation this plugin guarantees (both directions):**
1. Separate state file `.personas-active`; never reads/writes another plugin's state.
2. Separate namespace `/personas` + skills `create-persona` / `team`; no overlap with `/caveman*` / `/ponytail*`.
3. Never edits `settings.json` or any user file (Section 10 principle) — installing this can't disturb their settings-patched hooks.
4. Hook self-suppression matches only `^/personas` — never silences another plugin's command turns.
5. Hooks are self-contained and exit 0 — additive, never assume sole ownership of an event, never break if another plugin's hook also ran.

**Unavoidable shared reality (inherent to all lifecycle-hook plugins — mitigated, not eliminated):**
- **Token compounding** — each persona plugin re-injects per turn; Section 15 cuts only this plugin's share.
- **Instruction stacking** — simultaneous personas may pull in different directions; mediated by persona authorship (the bundled `contrarian` carries an "Interaction with caveman" clause; `create-persona` can prompt for coexistence notes).
- **Team-moderator cross-contamination** — the Section 7 fix suppresses only *this* plugin's persona on the moderator turn; other plugins' hooks still inject. A pristine debate needs the user to pause those too. Documented in the README "Coexistence" section.
