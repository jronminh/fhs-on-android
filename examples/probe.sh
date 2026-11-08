#!/system/bin/sh
# fhs-on-android -- host probe.
#
# Answers "what does this phone actually allow?" in one read-only run. It is
# written for Android's sh (mksh) and also runs under bash/dash on a Linux box.
#
# Usage:  sh probe.sh            (from adb shell, Termux, or an app's shell)
#
# The only write it performs is one temporary file in a writable directory, to
# test whether that directory is executable; the file is removed before exit.

NL='
'
say() { printf '\n== %s\n' "$1"; }
kv()  { printf '  %-22s %s\n' "$1" "$2"; }

# run LABEL -- CMD...   prints ok/fail with the first line of output
run() {
    label=$1; shift
    out=$("$@" 2>&1); rc=$?
    first=$(printf '%s' "$out" | head -n 1)
    if [ "$rc" -eq 0 ]; then
        printf '  ok     %-18s %s\n' "$label" "$first"
    else
        printf '  FAIL   %-18s rc=%s %s\n' "$label" "$rc" "$first"
    fi
}

has() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }
prop() { getprop "$1" 2>/dev/null || echo '(no getprop)'; }

printf 'fhs-on-android host probe\n'
printf 'date: %s\n' "$(date 2>/dev/null)"

say "identity"
kv model      "$(prop ro.product.model)"
kv android    "$(prop ro.build.version.release) / sdk $(prop ro.build.version.sdk)"
kv abi        "$(prop ro.product.cpu.abi)"
kv id         "$(id 2>&1)"
kv selinux    "$(getenforce 2>/dev/null || echo unknown)"
kv attr       "$(cat /proc/self/attr/current 2>/dev/null || echo unknown)"

say "kernel and memory"
kv kernel     "$(uname -r 2>/dev/null)"
kv arch       "$(uname -m 2>/dev/null)"
if command -v getconf >/dev/null 2>&1; then
    kv pagesize "$(getconf PAGESIZE 2>/dev/null)"
else
    kv pagesize "(no getconf; check the device's page size in its docs)"
fi
kv free       "$(free 2>/dev/null | sed -n 2p)"

say "sandbox (the three gates)"
kv seccomp    "$(grep '^Seccomp:' /proc/self/status 2>/dev/null || echo unknown)"
kv capEff     "$(grep '^CapEff:' /proc/self/status 2>/dev/null || echo unknown)"
kv noNewPrivs "$(grep '^NoNewPrivs:' /proc/self/status 2>/dev/null || echo unknown)"
kv zones      "$(ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null | wc -l) thermal zones"

say "the real root (what an FHS tree is missing here)"
for p in /lib /lib64 /usr/lib /usr/bin /etc/passwd /etc/resolv.conf /tmp; do
    if [ -e "$p" ]; then kv "$p" "exists"; else kv "$p" "ABSENT"; fi
done
kv linker64   "$(ls /system/bin/linker64 2>/dev/null || echo ABSENT)"

say "what is actually permitted here"
tmpd=/data/local/tmp
[ -w "$tmpd" ] || tmpd=${TMPDIR:-/cache}
if command -v chroot >/dev/null 2>&1; then
    run chroot    chroot / true
else
    kv chroot     "not installed"
fi
if command -v unshare >/dev/null 2>&1; then
    run unshare-userns unshare -Ur true
else
    kv unshare        "not installed (test with a static binary)"
fi
if command -v timeout >/dev/null 2>&1; then
    run ping-loopback timeout 3 ping -c 1 127.0.0.1
else
    kv ping           "skipped (no timeout(1))"
fi
probe_exec() {
    # can we write a file here AND execute it?  (targetSdk >= 29 says no)
    d=$1
    [ -d "$d" ] && [ -w "$d" ] || { printf '  skip   %-18s not writable\n' "exec $d"; return; }
    f="$d/.fhs-probe.$$"
    if cp /system/bin/sh "$f" 2>/dev/null; then
        "$f" -c 'exit 0' >/dev/null 2>&1
        rc=$?
        rm -f "$f"
        if [ "$rc" -eq 0 ]; then
            printf '  ok     %-18s writable + executable\n' "exec $d"
        else
            printf '  FAIL   %-18s writable but NOT executable\n' "exec $d"
        fi
    else
        printf '  skip   %-18s cannot write\n' "exec $d"
    fi
}
probe_exec "$tmpd"
[ -n "$TMPDIR" ] && probe_exec "$TMPDIR"
true

say "device nodes"
for d in /dev/null /dev/zero /dev/urandom /dev/tty /dev/net/tun /dev/fuse; do
    if [ -e "$d" ]; then kv "$d" "$(ls -l "$d" 2>/dev/null | cut -c1-10)"; else kv "$d" "ABSENT"; fi
done
gpu=""
for d in /dev/kgsl-3d0 /dev/mali* /dev/dri/*; do
    [ -e "$d" ] && gpu="$gpu $d"
done
kv gpu        "${gpu:- none found}"

say "tools present"
for t in busybox proot patchelf python3 tar gzip curl wget su; do kv "$t" "$(has $t)"; done

say "reading it"
cat <<'EOF'
  Seccomp 0            -> no app filter (Gate A absent): the easy domain
  Seccomp 2            -> filtered: an untrapped syscall kills the process
  CapEff low bits only -> no CAP_SYS_ADMIN: chroot/mount/unshare will fail
  /lib ABSENT          -> a Debian tree's PT_INTERP will not resolve at the root
  exec FAIL            -> apps at targetSdk >= 29: use userland exec, not execve
EOF
