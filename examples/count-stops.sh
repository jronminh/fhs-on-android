#!/bin/sh
# Before building a tracer, see what it would be paid per call: count the syscalls
# a workload makes. Every syscall a tracer stops is a stop.
#
# usage: count-stops.sh COMMAND...
# needs strace on the host that runs it (not on the phone).
set -u
command -v strace >/dev/null 2>&1 || { echo "strace not found: run this on a Linux host" >&2; exit 69; }
[ $# -ge 1 ] || { echo "usage: $0 COMMAND..." >&2; exit 64; }
echo "== $* =="
strace -f -c -q "$@" 2>&1 | tail -n 12
