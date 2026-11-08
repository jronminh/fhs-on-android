#!/bin/sh
# The guard behind "keep the distribution's libc, patch ten files": seed the
# patched copies into the tree's stash, then restore every canonical path whose
# content differs from the stash. That is the shape deb-native's dn-fix-glibc.sh
# uses, so an apt reinstall of libc6 cannot leave the tree on stock glibc
# without anyone noticing.
#
# It is an illustration, not a tool: it builds nothing, knows only the files in
# libc-swap.list beside it, and does not wire itself into apt.
#
# usage: libc-swap.sh TREE PATCHED
#   TREE     the tree whose libc is being replaced
#   PATCHED  a directory holding the swapped files at their tree-relative paths
set -u
[ $# -eq 2 ] || { echo "usage: $0 TREE PATCHED" >&2; exit 64; }
TREE=${1%/}
PATCHED=${2%/}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIST=$HERE/libc-swap.list
STASH=$TREE/usr/lib/deb-native/glibc-swap
fail() { echo "libc-swap: $*" >&2; exit 1; }

[ -d "$TREE" ] || fail "no tree at $TREE"
[ -d "$PATCHED" ] || fail "no patched set at $PATCHED"
[ -f "$LIST" ] || fail "no libc-swap.list beside this script"
mkdir -p "$STASH" || fail "cannot create $STASH"

# 1. The stash is the authority: the patched copies live here, and the paths the
#    loader reads are only copies of it.
n=0
while read -r rel; do
    case $rel in ''|'#'*) continue ;; esac
    [ -f "$PATCHED/$rel" ] || fail "the set has no $rel"
    mkdir -p "$(dirname "$STASH/$rel")" || fail "mkdir failed for $rel"
    cp -f "$PATCHED/$rel" "$STASH/$rel" || fail "cannot stash $rel"
    n=$((n + 1))
done < "$LIST"
printf 'stashed: %s files\n' "$n"

# 2. The restore, idempotent: only what differs, written beside its target and
#    renamed, so a running program never sees half a libc.
fixed=0
while read -r rel; do
    case $rel in ''|'#'*) continue ;; esac
    [ -e "$STASH/$rel" ] || continue
    if [ -e "$TREE/$rel" ] && cmp -s "$STASH/$rel" "$TREE/$rel"; then
        continue
    fi
    mkdir -p "$(dirname "$TREE/$rel")" || fail "mkdir failed for $rel"
    cp -f "$STASH/$rel" "$TREE/$rel.tmp.$$" || fail "cannot copy $rel"
    chmod 755 "$TREE/$rel.tmp.$$"
    mv -f "$TREE/$rel.tmp.$$" "$TREE/$rel" || fail "cannot install $rel"
    fixed=$((fixed + 1))
done < "$LIST"
printf 'restored: %s files\n' "$fixed"

# 3. What to wire into apt on a real tree (docs, not code): the same restore,
#    run from the post-invoke hook, so a libc6 reinstall cannot undo it.
if [ "$fixed" -eq 0 ]; then
    echo "the tree already carried the patched files" >&2
else
    echo "now check: ldd on a program in the tree, and 'getent passwd 2000'" >&2
fi
exit 0
