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

# INVARIANT: anything the host executes out of this repo gets a :ro mount below.
# The server is internet-facing and runs third-party plugins, so whatever stays
# writable is code those plugins can hand back to the operator to run.
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
  -v "$REPO_DIR/scripts:/minecraft/scripts:ro" \
  -v "$REPO_DIR/docker_run.sh:/minecraft/docker_run.sh:ro" \
  -v "$REPO_DIR/Dockerfile:/minecraft/Dockerfile:ro" \
  -w /minecraft \
  minecraft-server
