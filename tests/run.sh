#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
rc=0
for f in test_*.sh; do
  bash "$f" || rc=1
done
[ $rc -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit $rc
