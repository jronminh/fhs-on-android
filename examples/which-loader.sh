#!/bin/sh
# Which loader will the kernel open for this program, and does it exist in the tree?
# A static binary has no PT_INTERP and is reported as such - that is the whole
# difference between "a path problem" and "nothing can translate it".
#
# usage: which-loader.sh PROGRAM [TREE]
set -u
[ $# -ge 1 ] || { echo "usage: $0 PROGRAM [TREE]" >&2; exit 64; }
prog=$1
tree=${2:-/}

# readelf is Android 12+ (toybox). Without it this script cannot tell "static"
# from "no tool", and a wrong "static" is worse than no answer.
command -v readelf >/dev/null 2>&1 || { echo "readelf not found: cannot read PT_INTERP on this device" >&2; exit 69; }

interp=$(readelf -l "$prog" 2>/dev/null | sed -n 's/.*program interpreter: \(.*\)]/\1/p')
if [ -z "$interp" ]; then
    echo "static: no interpreter, nothing to resolve"
    exit 0
fi

printf 'interp: %s\n' "$interp"
case "$tree$interp" in
    /*) path=$(printf '%s' "$tree$interp" | sed 's://*:/:g') ;;
esac
if [ -e "$path" ]; then
    printf 'resolves: %s\n' "$path"
else
    printf 'MISSING: %s (execve answers ENOENT, naming no library)\n' "$path"
    exit 1
fi
