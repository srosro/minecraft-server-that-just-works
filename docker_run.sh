#!/usr/bin/env bash
# Start the Minecraft server container.
#
# The server files (paper.jar, world/, plugins/) live in this repo, so the repo
# itself is bind-mounted at /minecraft. A named volume would start out empty --
# nothing populates it -- and the server would have no jar to run.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

docker run -d \
  --name mc-server \
  --restart unless-stopped \
  --user "$(id -u):$(id -g)" \
  -p 25565:25565 \
  -p 19132:19132/udp \
  -v "$REPO_DIR:/minecraft" \
  -w /minecraft \
  minecraft-server \
  java -Xms2G -Xmx4G -jar paper.jar nogui
