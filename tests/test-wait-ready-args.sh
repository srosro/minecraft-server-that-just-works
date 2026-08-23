#!/usr/bin/env bash
# Pins the one invariant in this repo whose regression is silent RCE: wait-ready.sh's
# timeout argument must be validated BEFORE it reaches bash arithmetic, where an array
# subscript performs command substitution (`SECONDS[$(cmd)]` runs cmd).
#
# No docker stub needed -- validation happens before the first docker call, so a
# rejected argument exits 2 while an accepted one reaches docker and exits 1 on the
# absent container. That difference is the whole test.
#
#   tests/test-wait-ready-args.sh
set -uo pipefail

WAIT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/wait-ready.sh
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0

# An exit-code-only assertion would pass against a version that executes the payload
# and *then* rejects it, so every injection row also asserts the side effect never
# happened.
reject_and_no_exec() {
  local arg=$1 marker="$tmp/pwned"
  rm -f "$marker"
  "$WAIT" "${arg//__MARKER__/$marker}" >/dev/null 2>&1
  local rc=$?
  if [[ $rc -ne 2 ]]; then echo "FAIL: [$arg] expected exit 2, got $rc"; fails=$((fails+1)); return; fi
  if [[ -e $marker ]]; then echo "FAIL: [$arg] EXECUTED the payload"; fails=$((fails+1)); return; fi
  echo "ok: rejected without executing -- $arg"
}

reject() {
  local arg=$1
  "$WAIT" "$arg" >/dev/null 2>&1
  local rc=$?
  if [[ $rc -ne 2 ]]; then echo "FAIL: [$arg] expected exit 2, got $rc"; fails=$((fails+1)); return; fi
  echo "ok: rejected -- $arg"
}

accept() {   # accepted => gets past validation to docker, which exits 1 (no container)
  local arg=$1
  "$WAIT" "$arg" >/dev/null 2>&1
  local rc=$?
  if [[ $rc -eq 2 ]]; then echo "FAIL: [$arg] should be accepted, was rejected"; fails=$((fails+1)); return; fi
  echo "ok: accepted -- ${arg:-<default>}"
}

reject_and_no_exec 'SECONDS[$(touch __MARKER__)]'
reject_and_no_exec 'PATH[$(touch __MARKER__)]'
reject_and_no_exec 'DEADLINE[$(touch __MARKER__)]'
reject_and_no_exec 'x[$(touch __MARKER__)]'
reject 'abc'
reject '-5'
reject '1 2'
accept ''          # ${1:-900} defaults on empty as well as unset -- deliberate
accept '30'
accept '0900'      # base 10, not octal 576

if (( fails )); then echo "$fails failure(s)"; exit 1; fi
echo "all argument-validation checks passed"
