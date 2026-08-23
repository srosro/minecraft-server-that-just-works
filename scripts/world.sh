#!/usr/bin/env bash
# Back up the world. Run before any version bump: Minecraft upgrades world format on
# load and it is one-way.
#
#   scripts/world.sh backup [archive]   -> prints the archive path
#
# There is deliberately no `restore` subcommand. Rolling back is rare, and an
# automated one has to delete the live world before it can put the old one back --
# a bad trade for a path that runs once a year, if ever. The archive is a plain
# tarball; restore it by hand, with the server stopped. See the README.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Which world directories exist depends on the server version: through 1.21.x the
# nether and end were siblings (world_nether/, world_the_end/); 26.2 consolidates
# them into world/dimensions/. Detect rather than hardcode, so this keeps working
# across the upgrade that changes it. Prints only -- the caller decides what an
# empty result means, since an exit here would only leave a subshell.
world_dirs() {
  local d
  for d in world world_nether world_the_end; do
    [[ -d "$REPO_DIR/server/$d" ]] && printf '%s\n' "$d"
  done
  return 0
}

case "${1:-}" in
  backup)
    # Seconds, not just the date: this archive is the only rollback there is, and a
    # same-day re-run -- a retry, a second bump, the operator repeating "update and
    # run" -- would otherwise overwrite the pre-upgrade copy with a post-upgrade one.
    out=${2:-~/mc-backup-$(date +%F-%H%M%S).tar.gz}
    if [[ -e $out ]]; then
      echo "FATAL: $out already exists; pass an explicit path" >&2
      exit 1
    fi

    mapfile -t worlds < <(world_dirs)
    if (( ${#worlds[@]} == 0 )); then
      echo "FATAL: no world directory under server/" >&2
      exit 1
    fi

    if docker inspect mc-server >/dev/null 2>&1; then
      if ! docker stop -t 90 mc-server >/dev/null; then
        echo "FATAL: mc-server would not stop; refusing to archive a live world" >&2
        exit 1
      fi
    fi

    # Write aside and rename on success, so a tar that dies partway (ENOSPC on a Pi
    # archiving a multi-GB world) leaves no truncated file wearing the archive's name.
    # The Dockerfile rides along: it pins the Java version this jar needs, and Paper
    # refuses to start on a Java newer than it was built against, so a rollback has
    # to move the pin and the jar together.
    tar czf "$out.part" -C "$REPO_DIR" Dockerfile -C "$REPO_DIR/server" \
      "${worlds[@]}" plugins paper.jar
    mv "$out.part" "$out"
    echo "$out"
    ;;
  *)
    echo "usage: scripts/world.sh backup [archive]" >&2
    exit 2
    ;;
esac
