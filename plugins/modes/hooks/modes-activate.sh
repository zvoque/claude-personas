#!/usr/bin/env bash
# SessionStart hook.
# Belt-and-suspenders: when a session starts/resumes/clears/compacts with a mode
# already active, inject the persona once up front so it's in context before the
# first prompt (the tracker then re-asserts it each turn).
#
# Never blocks session start.

export LC_ALL=C
. "$(cd "$(dirname "$0")" && pwd)/modes-lib.sh"

cat >/dev/null 2>&1   # drain stdin (payload unused) so we don't hang on the pipe

active="$(get_active_mode)" || exit 0
[ -n "$active" ] || exit 0
persona="$(read_persona "$active")" || exit 0
[ -n "$persona" ] && emit_context "SessionStart" "$persona"
exit 0
