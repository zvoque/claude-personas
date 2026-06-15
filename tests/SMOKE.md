# Manual smoke checks (LLM/integration paths the unit tests can't cover)

Run in a real Claude Code session with the plugin installed. (Do the Task 0.5 spike first if not already done.)

## Functional
- [ ] `/personas contrarian` -> adopts contrarian this turn and persists next turns.
- [ ] `/personas off` -> reverts to normal next turn.
- [ ] `/personas parallel`, then enable two -> both answer in turn, labeled, one message.
- [ ] `/personas list` -> personas listed with `*` on active ones + the mode line.
- [ ] `/personas delete <name>` on a personal persona -> gone; on a bundled-only name -> refused.
- [ ] `/personas new` (Phase 2) / `/personas team` (Phase 3) -> report "ships in Phase N".

## Efficiency / no-lobotomy (gates promoting PERSONAS_TERSE to default)
- [ ] With `PERSONAS_TERSE=1` set, enable contrarian and run a 30+ turn session. Confirm it stays fully in character with only the short per-turn re-assertion. If it drifts -> keep full-per-turn as default (do NOT promote terse).

## Moderator neutrality (Phase 3 dependency, verify the hook half now)
- [ ] On a `/personas ...` turn, confirm the tracker injected nothing (the self-suppress fired) -- or that the hook didn't run at all on the command turn. Either is clean.
