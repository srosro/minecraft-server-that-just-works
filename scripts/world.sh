#!/usr/bin/env bash
# Back up or roll back the world. One home for the stop-the-server guard, because
# every destructive step here has to be preceded by a clean shutdown: tarring or
# overwriting a live world captures it mid-write.
#
#   scripts/world.sh backup            -> ~/mc-backup-<date>.tar.gz
#   scripts/world.sh restore <archive> -> puts that archive back, jar and Java pin together
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Which world directories exist depends on the server version: through 1.21.x the
# nether and end were siblings (world_nether/, world_the_end/); 26.2 consolidates
# them into world/dimensions/. Detect rather than hardcode, so this keeps working
# across the upgrade that changes it.
world_dirs() {
  local d found=()
  for d in world world_nether world_the_end; do
    [[ -d "$REPO_DIR/server/$d" ]] && found+=("$d")
  done
  (( ${#found[@]} )) || { echo "FATAL: no world directory under server/" >&2; exit 1; }
  printf '%s\n' "${found[@]}"
}

stop_server() {
  docker inspect mc-server >/dev/null 2>&1 || return 0   # nothing to stop
  docker stop -t 90 mc-server >/dev/null \
    || { echo "FATAL: mc-server would not stop; refusing to touch a live world" >&2; exit 1; }
}

case "${1:-}" in
  backup)
    out=${2:-~/mc-backup-$(date +%F).tar.gz}
    stop_server
    # The Dockerfile rides along: it pins the Java version this jar needs, and Paper
    # refuses to start on a Java newer than it was built against. Without it the
    # archive cannot reconstruct a bootable server.
    mapfile -t worlds < <(world_dirs)
    tar czf "$out" -C "$REPO_DIR" Dockerfile -C "$REPO_DIR/server" \
      "${worlds[@]}" plugins paper.jar
    echo "$out"
    ;;
  restore)
    archive=${2:?usage: scripts/world.sh restore <archive>}
    [[ -r $archive ]] || { echo "FATAL: cannot read $archive" >&2; exit 1; }
    stop_server
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    tar xzf "$archive" -C "$tmp"
    # Replace rather than merge: untarring over an upgraded world leaves new-format
    # chunks beside the old level.dat, which is the mixed state the one-way upgrade
    # warning exists to avoid.
    # Clear exactly what the archive carries, so a restore across the 1.21->26.2
    # dimension move doesn't leave the old world_nether/ beside the new world/.
    for w in "$tmp"/*; do
      [[ $(basename "$w") == Dockerfile ]] && continue
      rm -rf "${REPO_DIR:?}/server/$(basename "$w")"
    done
    mv "$tmp/Dockerfile" "$REPO_DIR/Dockerfile"
    mv "$tmp"/* "$REPO_DIR/server/"
    docker build -t minecraft-server "$REPO_DIR" >/dev/null
    echo "restored $archive — start with ./docker_run.sh"
    ;;
  *)
    echo "usage: scripts/world.sh backup [archive] | restore <archive>" >&2
    exit 2
    ;;
esac
