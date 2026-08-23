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
"$REPO_DIR/scripts/stop-server.sh"
docker rm mc-server >/dev/null 2>&1 || true

# Floodgate rewrites key.pem with the default mask whenever it regenerates, so the
# durable protection is on the directory: 700 denies traversal regardless of the
# file's own mode. That key forges Bedrock logins as any user, op included.
[[ -d "$REPO_DIR/server/plugins/floodgate" ]] && chmod 700 "$REPO_DIR/server/plugins/floodgate"

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
