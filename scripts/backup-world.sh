#!/usr/bin/env bash
# Back up the world before a version bump: Minecraft upgrades world format on load
# and it is one-way.
#
#   scripts/backup-world.sh   -> prints the archive path
#
# Backup is the only automated world operation, on purpose. Restoring is rare and an
# automated one has to delete the live world before it can put the old one back --
# a bad trade. The archive is a plain tarball; the README covers putting it back.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# 1.21.x kept the nether and end as siblings; 26.2 consolidates them into
# world/dimensions/. Take whichever this tree has.
worlds=(world)
for d in world_nether world_the_end; do
  if [[ -d "$REPO_DIR/server/$d" ]]; then worlds+=("$d"); fi
done

# Seconds, not just the date: this archive is the only rollback there is, and a
# same-day re-run would otherwise overwrite a pre-upgrade copy with a post-upgrade one.
out=~/mc-backup-$(date +%F-%H%M%S).tar.gz
# ...and still refuse an existing target. Two runs inside one second collide, which
# is not hypothetical: it happened while testing this script.
for f in "$out" "$out.part"; do
  if [[ -e $f ]]; then
    echo "FATAL: $f already exists; wait a second and retry" >&2
    exit 1
  fi
done

if docker inspect mc-server >/dev/null 2>&1; then
  if ! docker stop -t 90 mc-server >/dev/null; then
    echo "FATAL: mc-server would not stop; refusing to archive a live world" >&2
    exit 1
  fi
  # docker stop SIGKILLs on timeout and still exits 0; a 137 means the world was
  # killed mid-save, so archiving it would capture exactly the torn state a backup
  # exists to avoid.
  if [[ $(docker inspect -f '{{.State.ExitCode}}' mc-server 2>/dev/null) == 137 ]]; then
    echo "FATAL: mc-server was killed after failing to save within 90s; refusing to" >&2
    echo "archive a possibly torn world." >&2
    exit 1
  fi
fi

# Write aside and rename, so a tar that dies on a full disk leaves no truncated file
# wearing the archive's name -- and no orphan eating the space the retry needs.
# The Dockerfile rides along: it pins the Java version this jar needs.
# Owner-only: the archive contains plugins/floodgate/key.pem, the shared secret that
# lets a Bedrock login skip Mojang auth. Default 644 on a traversable home hands any
# local account the ability to join as an arbitrary user, op included.
umask 077
trap 'rm -f "$out.part"' EXIT
tar czf "$out.part" -C "$REPO_DIR" Dockerfile -C "$REPO_DIR/server" \
  "${worlds[@]}" plugins paper.jar
mv "$out.part" "$out"
echo "$out"
