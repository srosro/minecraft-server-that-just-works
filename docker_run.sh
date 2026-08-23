#!/usr/bin/env bash
# Start the Minecraft server container.
#
# The server files (paper.jar, world/, plugins/) live in this repo, so the repo
# itself is bind-mounted at /minecraft. A named volume would start out empty --
# nothing populates it -- and the server would have no jar to run.
#
# The java command lives in the image's CMD, not here, so heap settings have a
# single home. Override it by appending args: ./docker_run.sh java -Xmx6G ...
#
# Removes an existing mc-server first so re-running this is safe. Stop the
# server with `docker stop -t 90 mc-server` before re-running, so the world
# gets flushed -- a forced removal mid-save corrupts chunks.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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
  -w /minecraft \
  minecraft-server "$@"
