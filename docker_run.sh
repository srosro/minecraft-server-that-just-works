#!/usr/bin/env bash
# Start the Minecraft server container.
#
# Everything the server owns lives under server/, and that is the ONLY thing bind-
# mounted. The repo root -- README.md, Dockerfile, this script, scripts/ -- stays
# outside the container by construction, because all of it is read and executed on
# the host, and the server is internet-facing running third-party plugins. Keeping
# the boundary structural means there is no allowlist to keep in sync: put host-read
# files at the root, server-owned state under server/.
#
# The java command lives in the image's CMD, not here, so heap settings have a
# single home: change CMD in the Dockerfile and rebuild.
#
# Safe to re-run: any existing mc-server is shut down cleanly first. The stop
# comes before the remove because `docker rm -f` sends SIGKILL, and killing the
# server mid-save corrupts chunks. Both are no-ops if it isn't running.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# A checkout from before the server/ split has its worlds at the repo root. Starting
# with the new mount would generate a fresh empty world while the real save sits one
# directory up, so refuse. This lives here rather than in the README because
# docker_run.sh exists in the old checkout too -- a README note isn't read until
# after the pull that strands the save.
stale=()
for d in world world_nether world_the_end; do
  if [[ -d "$REPO_DIR/$d" ]]; then stale+=("$d"); fi
done
if (( ${#stale[@]} )); then
  echo "FATAL: found at the repo root: ${stale[*]}" >&2
  echo "" >&2
  echo "This checkout predates the server/ layout. Those directories are your live" >&2
  echo "save; git left them because they are untracked at that path. Move each one" >&2
  echo "under $REPO_DIR/server/ (replacing the older tracked copy, if any), keeping" >&2
  echo "a tar of it first, then re-run this script." >&2
  exit 1
fi

docker stop -t 90 mc-server 2>/dev/null || true
docker rm -f mc-server 2>/dev/null || true

docker run -d \
  --name mc-server \
  --restart unless-stopped \
  --user "$(id -u):$(id -g)" \
  --memory=5g --memory-swap=5g \
  -p 25565:25565 \
  -p 19132:19132/udp \
  -v "$REPO_DIR/server:/minecraft" \
  -w /minecraft \
  minecraft-server
