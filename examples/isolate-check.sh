#!/system/bin/sh
# Can this domain isolate a tree? Two read-only checks, and the honest answer is
# usually "no" - which is why isolation is a cost, not a feature.
#
# usage: isolate-check.sh [TREE]
tree=${1:-/}
printf 'uid=%s\n' "$(id -u 2>/dev/null)"
printf 'seccomp=%s\n' "$(sed -n 's/^Seccomp:[[:space:]]*//p' /proc/self/status 2>/dev/null)"

if command -v chroot >/dev/null 2>&1; then
    if chroot "$tree" true >/dev/null 2>&1; then echo "chroot: ok"; else echo "chroot: refused ($?)"; fi
else
    echo "chroot: not installed"
fi

if command -v unshare >/dev/null 2>&1; then
    if unshare -Ur true >/dev/null 2>&1; then echo "userns: ok"; else echo "userns: refused ($?)"; fi
else
    echo "unshare: not installed (a static binary is the honest test)"
fi
