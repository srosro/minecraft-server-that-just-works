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
REJECTED='must be a whole number'   # the validator's own words -- see below

# Without `timeout` the accept rows would fail open and the suite would pass silently.
command -v timeout >/dev/null || { echo "FATAL: needs 'timeout' (coreutils)" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0

# An exit-code-only assertion would pass against a version that executes the payload
# and *then* rejects it, so every injection row also asserts the side effect never
# happened.
# Assertions match the validator's message, not just the exit code: a script that
# exited 2 unconditionally, or 0 unconditionally, would satisfy exit codes alone while
# doing nothing. The message only appears when validation actually rejected.
reject_and_no_exec() {
  local arg=$1 marker="$tmp/pwned" out rc
  rm -f "$marker"
  out=$("$WAIT" "${arg//__MARKER__/$marker}" 2>&1); rc=$?
  if [[ -e $marker ]]; then echo "FAIL: [$arg] EXECUTED the payload"; fails=$((fails+1)); return; fi
  if [[ $rc -ne 2 ]] || ! grep -qF "$REJECTED" <<<"$out"; then
    echo "FAIL: [$arg] expected rejection (exit 2 + validator message), got rc=$rc"; fails=$((fails+1)); return
  fi
  echo "ok: rejected without executing -- $arg"
}

reject() {
  local arg=$1 out rc
  out=$("$WAIT" "$arg" 2>&1); rc=$?
  if [[ $rc -ne 2 ]] || ! grep -qF "$REJECTED" <<<"$out"; then
    echo "FAIL: [$arg] expected rejection (exit 2 + validator message), got rc=$rc"; fails=$((fails+1)); return
  fi
  echo "ok: rejected -- $arg"
}

# Accepted means "got past validation". What happens after depends on whether an
# mc-server container happens to exist on this host, so this asserts only `not 2` and
# caps the wall clock: with a container present but still booting, an accepted 0900
# would otherwise poll for fifteen minutes. timeout's 124 is still `not 2`.
accept() {
  local arg=$1 out
  out=$(timeout 3 "$WAIT" "$arg" 2>&1 || true)
  if grep -qF "$REJECTED" <<<"$out"; then
    echo "FAIL: [$arg] should be accepted, was rejected"; fails=$((fails+1)); return
  fi
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
