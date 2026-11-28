#!/usr/bin/env bash
# btrfs-snapshot — read-only snapshots of @home, so losing a file is a 10-second fix.
#
# Why: PLAN.md was truncated to 0 bytes by one bad write. There were no btrfs
# snapshots, no copies, and it was outside the backup include list. Nightly restic
# would still have lost up to a day of edits. A COW snapshot costs almost nothing
# and makes *any* file recoverable at 15-minute granularity.
#
# Runs as root (system timer): snapshotting and mounting subvolumes needs
# CAP_SYS_ADMIN, which is why this is not a user unit.
#
# Install (see the docs block) as:
#   /usr/local/bin/btrfs-snapshot
#   /etc/systemd/system/btrfs-snapshot.{service,timer}
#
# Restore a single file:
#   SNAP=/mnt/btrfs/snapshots/home-<stamp>
#   # mount the top level first: sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt/btrfs
#   cp "$SNAP/alex/PLAN.md" /home/alex/PLAN.md
set -euo pipefail

DEV=/dev/nvme0n1p2      # verify with: findmnt -no SOURCE /home
TOP=/mnt/btrfs          # where the btrfs top level gets mounted, on demand
DEST="$TOP/snapshots"
KEEP_DAYS=7

mounted_by_us=0
if ! mountpoint -q "$TOP"; then
  mkdir -p "$TOP"
  mount -o subvolid=5 "$DEV" "$TOP"
  mounted_by_us=1
fi

cleanup() {
  [ "$mounted_by_us" = 1 ] && umount "$TOP" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$DEST"
stamp=$(date +%Y-%m-%d_%H%M)
snap="$DEST/home-$stamp"

if [ -e "$snap" ]; then
  echo "snapshot $snap already exists; nothing to do"
  exit 0
fi

btrfs subvolume snapshot -r "$TOP/@home" "$snap" >/dev/null
echo "created $snap"

# Retention. Snapshots share blocks, so age is the only thing worth bounding.
while IFS= read -r -d '' old; do
  btrfs subvolume delete "$old" >/dev/null && echo "pruned $old"
done < <(find "$DEST" -maxdepth 1 -type d -name 'home-*' -mtime "+$KEEP_DAYS" -print0)
