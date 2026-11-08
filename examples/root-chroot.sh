#!/system/bin/sh
# Level 4, the smallest form: build an FHS-shaped directory out of one static
# busybox, bind the kernel filesystems into it, and enter it with chroot.
#
# Needs root (uid 0) and a static busybox. Writes only under TREE, and removes
# it on exit unless KEEP=1.
#
#   su -c 'BUSYBOX=/data/adb/magisk/busybox TREE=/data/local/tmp/tree sh root-chroot.sh'
#
# The lesson in the symlinks: absolute applet links would name the tree's path
# from outside, which does not exist once you are inside. Relative, or nothing.
set -u

BUSYBOX=${BUSYBOX:-/data/adb/magisk/busybox}
TREE=${TREE:-/data/local/tmp/fhs-tree}
KEEP=${KEEP:-0}
log() { printf '%s\n' "$*"; }

[ "$(id -u)" = 0 ] || { log "needs root"; exit 64; }
[ -x "$BUSYBOX" ] || { log "no busybox at $BUSYBOX"; exit 64; }
if readelf -l "$BUSYBOX" 2>/dev/null | grep -q 'program interpreter'; then
    log "busybox is dynamic: this tree would need a loader too"; exit 65
fi

rm -rf "$TREE"
mkdir -p "$TREE/bin" "$TREE/etc" "$TREE/tmp" "$TREE/proc" "$TREE/sys" "$TREE/dev"
cp "$BUSYBOX" "$TREE/bin/busybox"
chmod 755 "$TREE/bin/busybox"
(cd "$TREE/bin" && "$TREE/bin/busybox" --list | while read -r a; do ln -sfn busybox "$a"; done)
printf 'root:x:0:0:root:/root:/bin/sh\n' > "$TREE/etc/passwd"
printf 'root:x:0:\n' > "$TREE/etc/group"
printf 'nameserver 1.1.1.1\n' > "$TREE/etc/resolv.conf"
chmod 1777 "$TREE/tmp"

log "tree: $(ls "$TREE/bin" | wc -l) applets, $(du -skx "$TREE" | awk '{print $1}') KB"

mount -t proc proc "$TREE/proc" || log "mount proc: failed"
mount -t sysfs sysfs "$TREE/sys" || log "mount sys: failed"
mount -o bind /dev "$TREE/dev" || log "bind /dev: failed"

cleanup() {
    # Lazy unmount first; a busy /dev bind makes rm descend into the real /dev.
    umount -l "$TREE/dev" 2>/dev/null
    umount "$TREE/sys" 2>/dev/null
    umount "$TREE/proc" 2>/dev/null
    mount | grep -q "$TREE" && { echo "still mounted: not removing"; return 1; }
    [ "$KEEP" = 1 ] || rm -rf "$TREE"
}
trap cleanup EXIT

chroot "$TREE" /bin/sh -c '
  export PATH=/bin
  printf "id       : %s\n" "$(id)"
  printf "kernel   : %s\n" "$(uname -r)"
  printf "rootfs   : %s\n" "$(ls / | tr "\n" " ")"
  printf "proc     : %s\n" "$(cut -c1-46 /proc/version)"
  printf "static   : %s\n" "$(/bin/busybox echo runs)"
  printf "isolation: /system -> %s\n" "$(ls /system 2>&1 | head -n 1)"
'
