#!/system/bin/sh
# A glibc tree under chroot: the smallest tree that runs a dynamic program, and
# the two ways it fails first. Needs root, and a glibc userland to take three
# files from (a Debian arm64 prefix works: bin/dash, libc, ld-linux).
#
#   su -c 'SRC=/data/local/tmp/p-shell sh glibc-chroot.sh'
#
# The three states are the point: no loader is ENOENT, an unexecutable loader is
# EACCES, and only 0755 runs. adb push writes 0644, so the second one is the trap
# that costs an hour if you do not know it.
set -u
SRC=${SRC:?set SRC to a directory holding usr/bin/dash and usr/lib/aarch64-linux-gnu/}
TREE=${TREE:-/data/adb/glibc-tree}
LD=lib/aarch64-linux-gnu/ld-linux-aarch64.so.1
log() { printf "%s\n" "$*"; }
[ "$(id -u)" = 0 ] || { log "needs root"; exit 64; }
[ -x "$SRC/usr/bin/dash" ] || { log "no $SRC/usr/bin/dash"; exit 64; }

rm -rf "$TREE"
mkdir -p "$TREE/bin" "$TREE/lib/aarch64-linux-gnu" "$TREE/etc" "$TREE/tmp" "$TREE/proc" "$TREE/sys" "$TREE/dev"
cp "$SRC/usr/bin/dash" "$TREE/bin/dash"; chmod 755 "$TREE/bin/dash"; ln -sfn dash "$TREE/bin/sh"
cp "$SRC/usr/lib/aarch64-linux-gnu/libc.so.6" "$TREE/lib/aarch64-linux-gnu/libc.so.6"
cp "$SRC/usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1" "$TREE/$LD"; chmod 755 "$TREE/$LD"
printf "root:x:0:0:root:/root:/bin/sh\n" > "$TREE/etc/passwd"
chmod 1777 "$TREE/tmp"
log "tree: $(du -skx "$TREE" | awk '{print $1}') KB"

log "A) no loader ->"
chroot "$TREE" /bin/sh -c "echo inside" 2>&1 | head -n 1
ln -sfn aarch64-linux-gnu/ld-linux-aarch64.so.1 "$TREE/lib/ld-linux-aarch64.so.1"

log "B) loader present, 0644 ->"
chmod 644 "$TREE/$LD"
chroot "$TREE" /bin/sh -c "echo inside" 2>&1 | head -n 1
chmod 755 "$TREE/$LD"

log "C) loader present and executable ->"
mount -t proc proc "$TREE/proc" 2>/dev/null || log "mount proc: failed"
mount -t sysfs sysfs "$TREE/sys" 2>/dev/null || log "mount sys: failed"
mount -o bind /dev "$TREE/dev" 2>/dev/null || log "bind /dev: failed"
chroot "$TREE" /lib/ld-linux-aarch64.so.1 --version 2>&1 | head -n 1 | sed "s/^/   /"
chroot "$TREE" /bin/sh -c '
  read v < /proc/version; echo "   proc  : $v" | cut -c1-50
  echo "   math  : $((6*7))"
  [ -d /system ] && echo "   system: present" || echo "   system: absent"
'
log "exit: $?"
umount "$TREE/dev" 2>/dev/null; umount "$TREE/sys" 2>/dev/null; umount "$TREE/proc" 2>/dev/null
rm -rf "$TREE"
log "cleanup done"
