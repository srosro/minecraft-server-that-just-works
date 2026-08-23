#!/usr/bin/env bash
# Start the Minecraft server container.
#
# The server files (paper.jar, world/, plugins/) live in this repo, so the repo
# itself is bind-mounted at /minecraft. A named volume would start out empty --
# nothing populates it -- and the server would have no jar to run.
#
# The java command lives in the image's CMD, not here, so heap settings have a
# single home: change CMD in the Dockerfile and rebuild.
#
# Safe to re-run: any existing mc-server is shut down cleanly first. The stop
# comes before the remove because `docker rm -f` sends SIGKILL, and killing the
# server mid-save corrupts chunks. Both are no-ops if it isn't running.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Anything the host executes out of this repo belongs in here. The server is
# internet-facing and runs third-party plugins, so whatever stays writable is code
# those plugins can hand back to the operator to run. Add to this list, not below.
HOST_EXECUTABLE_RO=(
  -v "$REPO_DIR/scripts:/minecraft/scripts:ro"
  -v "$REPO_DIR/docker_run.sh:/minecraft/docker_run.sh:ro"
  -v "$REPO_DIR/Dockerfile:/minecraft/Dockerfile:ro"
)

docker stop -t 90 mc-server 2>/dev/null || true
docker rm -f mc-server 2>/dev/null || true

docker run -d \
  --name mc-server \
  --restart unless-stopped \
  --user "$(id -u):$(id -g)" \
  --memory=5g --memory-swap=5g \
  -p 25565:25565 \
  -p 19132:19132/udp \
  -v "$REPO_DIR:/minecraft" \
  -v /minecraft/.git \
  "${HOST_EXECUTABLE_RO[@]}" \
  -w /minecraft \
  minecraft-server
