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

# A swallowed stop failure followed by `rm -f` is a SIGKILL to a running server,
# which is the mid-save chunk corruption this script's own -t 90 exists to avoid.
# Same inspect-gated, fail-loud handling as scripts/backup-world.sh.
if docker inspect mc-server >/dev/null 2>&1; then
  if ! docker stop -t 90 mc-server >/dev/null; then
    echo "FATAL: mc-server would not stop; refusing to force-remove a live server" >&2
    exit 1
  fi
  docker rm mc-server >/dev/null
fi

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
