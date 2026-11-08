#!/bin/sh
# Own the build instead of translating the program: compile it against bionic,
# then look for absolute paths the tree has to teach it.
#
# usage: CC=<ndk-clang> build-bionic.sh FILE.c
#   CC is e.g. aarch64-linux-android29-clang from the NDK.
#   On a phone, clang from the Termux package works too; the target is the phone.
set -eu
[ $# -eq 1 ] || { echo "usage: CC=<clang> $0 FILE.c" >&2; exit 64; }
src=$1
out=${src%.c}
: "${CC:?set CC to a compiler that targets Android (NDK clang)}"

"$CC" -O2 -Wall -o "$out" "$src"
printf 'built: %s\n' "$out"

# Paths the program owns and the tree must provide: these are what "teaching"
# means, and what a run-time layer cannot reach inside a static binary.
if command -v strings >/dev/null 2>&1; then
    printf 'absolute paths in the binary:\n'
    strings "$out" | grep '^/[a-z]' | sort -u | head -n 20 || true
fi
