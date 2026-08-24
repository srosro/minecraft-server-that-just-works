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

if ! docker stop -t 90 mc-server >/dev/null; then
  echo "FATAL: mc-server would not stop; refusing to act on a live world" >&2
  exit 1
fi

exit_code=$(docker inspect -f '{{.State.ExitCode}}' mc-server)

# 137 is SIGKILL -- `docker stop` escalates to it once its timeout expires and still
# exits 0, so the shutdown that tears a world reports success. Whether this stop
# caused it or an earlier kill did doesn't change what happens next, so it isn't
# tracked: either way the world is suspect and the container has to be recreated.
if [[ $exit_code == 137 ]]; then
  echo "REFUSING: mc-server last exited on SIGKILL, so the world may be torn mid-write." >&2
  echo "Check it, then: docker rm mc-server && ./docker_run.sh" >&2
  echo "(docker rm removes the container, so recreate rather than 'docker start'.)" >&2
  exit 1
fi
