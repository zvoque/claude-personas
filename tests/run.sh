#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
rc=0
for f in "$ROOT"/.claude-plugin/marketplace.json \
         "$ROOT"/plugins/personas/.claude-plugin/plugin.json \
         "$ROOT"/plugins/personas/hooks/hooks.json; do
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null \
    && echo "ok json $(basename "$f")" || { echo "BAD json $f"; rc=1; }
done
for f in test_*.sh; do bash "$f" || rc=1; done
[ $rc -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit $rc
