#!/bin/sh
# Rewrite PT_INTERP of every dynamic ELF under a directory, so the tree's own
# loader is found at exec time. Idempotent: a file already pointing at the loader
# is left alone, and a static binary or a shared library (no PT_INTERP) is skipped.
#
# usage: elf-interp.sh TREE TREE/lib/ld-linux-aarch64.so.1 [--dry-run]
# needs patchelf on the host that runs it, not on the phone.
set -eu

[ $# -ge 2 ] || { echo "usage: $0 TREE LOADER [--dry-run]" >&2; exit 64; }
tree=$1
loader=$2
dry=0
[ "${3:-}" = "--dry-run" ] && dry=1

command -v patchelf >/dev/null 2>&1 || { echo "patchelf not found: run this on the host, not on the phone" >&2; exit 69; }

elf() {
    [ -f "$1" ] || return 1
    [ "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ]
}

find "$tree" -type f 2>/dev/null | while IFS= read -r f; do
    elf "$f" || continue
    cur=$(patchelf --print-interpreter "$f" 2>/dev/null) || continue   # no PT_INTERP
    [ "$cur" = "$loader" ] && continue
    if [ "$dry" = 1 ]; then
        printf 'would set: %s\n  was: %s\n  now: %s\n' "$f" "$cur" "$loader"
    else
        patchelf --set-interpreter "$loader" "$f"
        printf 'set: %s\n' "$f"
    fi
done
