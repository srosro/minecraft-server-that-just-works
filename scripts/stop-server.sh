#!/usr/bin/env bash
# The canonical way to stop this server. Use it instead of `docker stop` anywhere:
# a raw stop escalates to SIGKILL once its timeout expires and still reports success,
# so it can tear a world mid-save and tell you it went fine.
#
# Exits 0 when the server is stopped (or was never there), non-zero when it isn't
# safe to act on the world.
set -euo pipefail

# A failing `docker ps` means the daemon is unreachable, which is NOT the same as
# "no such container". Reading one as the other would let a backup archive a world
# that is still running.
if ! existing=$(docker ps -aq --filter 'name=^mc-server$'); then
  echo "FATAL: cannot reach the Docker daemon; refusing to act on a possibly-live world" >&2
  exit 1
fi
[[ -n $existing ]] || exit 0   # confirmed absent, nothing to do

# Captured before the stop: .State.ExitCode is persisted from whenever the container
# last exited, so an already-stopped one carries a code this stop did not produce.
was_running=$(docker inspect -f '{{.State.Running}}' mc-server)

if ! docker stop -t 90 mc-server >/dev/null; then
  echo "FATAL: mc-server would not stop; refusing to act on a live world" >&2
  exit 1
fi

exit_code=$(docker inspect -f '{{.State.ExitCode}}' mc-server)

if [[ $was_running != true ]]; then
  # Unattributable: a 137 here could be from this stop or a kill last week. Blocking
  # would wedge the operator on stale state; silence would hide a torn world.
  if [[ $exit_code == 137 ]]; then
    echo "WARNING: mc-server was already stopped and last exited on SIGKILL." >&2
    echo "If that was recent, the world may be mid-write -- check it." >&2
  fi
  exit 0
fi

# This one is ours: it was running a moment ago. 137 is SIGKILL, from the stop
# timeout expiring or from the memory cap.
if [[ $exit_code == 137 ]]; then
  echo "FATAL: mc-server was killed during shutdown -- the save exceeded 90s, or it" >&2
  echo "hit the memory cap. The world may be mid-write. Check it, then clear this" >&2
  echo "state with: docker rm mc-server" >&2
  exit 1
fi
