#!/usr/bin/env bash
# Shared clean-shutdown helper: source this, then call stop_mc_server.
#
# Both callers must refuse to proceed over a world that may be mid-write -- one is
# about to recreate the container over it, the other about to archive it as a rollback.

stop_mc_server() {
  docker inspect mc-server >/dev/null 2>&1 || return 0   # nothing to stop

  # Captured BEFORE the stop: .State.ExitCode is persisted from whenever the container
  # last exited, so an already-stopped container carries a stale code. Without this
  # gate a 137 from an unrelated earlier OOM or `docker kill` would refuse forever,
  # with no way to clear it.
  local was_running
  was_running=$(docker inspect -f '{{.State.Running}}' mc-server 2>/dev/null || echo false)

  docker stop -t 90 mc-server >/dev/null || {
    echo "FATAL: mc-server would not stop; refusing to act on a live world" >&2
    return 1
  }
  [[ $was_running == true ]] || return 0

  # `docker stop` escalates to SIGKILL once its timeout expires and still exits 0, so
  # the shutdown that actually tears chunks reports success. 137 is SIGKILL.
  [[ $(docker inspect -f '{{.State.ExitCode}}' mc-server 2>/dev/null) == 137 ]] || return 0

  if [[ $(docker inspect -f '{{.State.OOMKilled}}' mc-server 2>/dev/null) == true ]]; then
    echo "FATAL: mc-server was OOM-killed during shutdown; the world may be mid-write." >&2
  else
    echo "FATAL: mc-server did not finish saving within 90s and was killed; the world" >&2
    echo "may be mid-write." >&2
  fi
  echo "Check the world before using it again, then clear this state with:" >&2
  echo "  docker rm mc-server" >&2
  return 1
}
