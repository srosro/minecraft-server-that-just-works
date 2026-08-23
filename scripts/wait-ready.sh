#!/usr/bin/env bash
# Wait for the server to finish starting. Exits 0 on ready, non-zero if it crashed,
# isn't there, or ran out of time -- so a runbook can chain on it.
#
#   scripts/wait-ready.sh [seconds]     (default 900)
set -euo pipefail

DEADLINE=${1:-900}

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
  # Scoped to this boot: `docker logs` replays the container's whole history, so a
  # ready line from a previous run would otherwise satisfy this instantly -- reachable
  # via `docker start` or a host reboot.
  since=$(docker inspect -f '{{.State.StartedAt}}' mc-server 2>/dev/null || echo)

  # Paper's own line, not Geyser's. Geyser logs "Done (1.7s)! Run /geyser help for
  # help!" during plugin enable, before Paper has bound 25565 -- matching that reports
  # ready while the Java port is still closed.
  if [[ -n $since ]] && docker logs --since "$since" mc-server 2>&1 \
       | grep -q 'Done (.*)! For help, type'; then
    echo "READY"
    exit 0
  fi

  state=$(docker inspect -f '{{.State.Status}}/{{.RestartCount}}' mc-server 2>/dev/null || echo "gone/-")
  if [[ $state != "running/$baseline" ]]; then
    echo "FATAL: mc-server is not healthy ($state) -- docker logs --tail 50 mc-server" >&2
    exit 1
  fi
  sleep 5
done

echo "FATAL: mc-server not ready after ${DEADLINE}s -- docker logs --tail 50 mc-server" >&2
exit 1
