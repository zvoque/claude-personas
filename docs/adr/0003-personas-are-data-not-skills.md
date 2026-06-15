# 3. Personas are data files, not skills

Date: 2026-06-15
Status: Accepted

## Context

v1 stored each persona as a `SKILL.md` so `/contrarian` worked as a native skill
invocation. ADR 0001 made control command-only, removing that reason. But the
skill-ness was left in place — and a persona stored as a skill *with a
description* is auto-discoverable: Claude can invoke a `contrarian` skill
mid-task on its own, with no `/personas` activation, subverting the controlled
on/off model. It also pollutes the skill/`/` menu with every user persona.

## Decision

A persona is a plain markdown **data file** `personas/<name>.md`, never registered
as a skill. Frontmatter is just `name` + `description`; no `persona: true` marker
(the directory is the namespace). Stored bundled in
`${CLAUDE_PLUGIN_ROOT}/personas/` and personal in `~/.claude/personas/`
(personal **overrides** bundled on name collision). Only the hook, the CLI, and
the `team` skill read these files. `create-persona` and `team` remain real
(discoverable) skills; personas do not.

## Consequences

- No rogue auto-activation; personas are OFF unless `/personas <name>` enables
  them. No skill-menu pollution.
- Cleaner separation: personas are plugin data, hooks/CLI are the engine, and the
  two real skills are the only Claude-facing surface.
- Cost: a persona can no longer be invoked as a one-shot skill — already
  surrendered by ADR 0001, so no real loss.
- Enabled by the single-user clean-reinstall (no migration of v1's
  `skills/<name>/SKILL.md` layout needed).
