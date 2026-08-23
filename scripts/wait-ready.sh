#!/usr/bin/env bash
# Wait for the server to finish starting. Exits 0 on ready, non-zero if it crashed,
# isn't there, or ran out of time -- so a runbook can chain on it.
#
#   scripts/wait-ready.sh [seconds]     (default 900)
set -euo pipefail

DEADLINE=${1:-900}

# Validate before any arithmetic. Bash evaluates a variable's *contents* as an
# arithmetic expression, and an array subscript there performs command substitution:
# `SECONDS[$(cmd)]` runs cmd. `set -u` is not a defense -- it only catches payloads
# naming an unset variable, and one naming a set variable executes silently.
if [[ ! $DEADLINE =~ ^[0-9]+$ ]]; then
  echo "FATAL: timeout must be a whole number of seconds (got: ${DEADLINE})" >&2
  exit 2
fi
DEADLINE=$((10#$DEADLINE))   # base 10 explicitly, so 0900 isn't read as octal

# RestartCount, not .State.Running: Docker reports Running=true for the whole restart
# backoff ("we should consider the container running when it is restarting"), and
# docker_run.sh always uses --restart unless-stopped -- so a crash-looping server
# never appears stopped. Sampling .State.Status alone has the same hole, since a fast
# loop spends most of each poll window in `running`.
if ! baseline=$(docker inspect -f '{{.RestartCount}}' mc-server 2>/dev/null); then
  echo "FATAL: no mc-server container -- start it with ./docker_run.sh" >&2
  exit 1
fi

end=$((SECONDS + DEADLINE))
while (( SECONDS < end )); do
  # Liveness FIRST. A stopped container's StartedAt is its last boot, and that boot's
  # log still holds its ready line -- checking the log first would report READY for a
  # server that is down, which stop-server.sh leaves as the normal resting state.
  state=$(docker inspect -f '{{.State.Status}}/{{.RestartCount}}' mc-server 2>/dev/null || echo "gone/-")
  if [[ $state != "running/$baseline" ]]; then
    echo "FATAL: mc-server is not healthy ($state) -- docker logs --tail 50 mc-server" >&2
    exit 1
  fi

  # Scoped to this boot: `docker logs` replays the container's whole history, so a
  # ready line from a previous run would otherwise satisfy this instantly.
  since=$(docker inspect -f '{{.State.StartedAt}}' mc-server 2>/dev/null || echo)

  # Process substitution, not a pipe: `grep -q` exits on the first match and closes the
  # pipe, docker logs takes SIGPIPE, and `set -o pipefail` would turn that genuine
  # match into a failure.
  #
  # Paper's own line, not Geyser's. Geyser logs "Done (1.7s)! Run /geyser help for
  # help!" during plugin enable, before Paper has bound 25565.
  if [[ -n $since ]] && grep -q 'Done (.*)! For help, type' \
       < <(docker logs --since "$since" mc-server 2>&1); then
    echo "READY"
    exit 0
  fi

  sleep 5
done

echo "FATAL: mc-server not ready after ${DEADLINE}s -- docker logs --tail 50 mc-server" >&2
exit 1
