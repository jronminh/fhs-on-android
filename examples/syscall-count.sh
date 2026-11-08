#!/bin/sh
# Count the real arm64 syscalls a kernel's header defines -- the table in
# reference/syscalls.md, reproduced from the kernel's own tags instead of
# trusted. It reads a header; it runs nothing on a phone.
#
# usage: syscall-count.sh unistd.h
#   curl -sO https://raw.githubusercontent.com/torvalds/linux/v6.12/include/uapi/asm-generic/unistd.h
#   syscall-count.sh unistd.h
#
# The rule, and why it is this rule: arm64 uses one generic table, `#define
# __NR_name N` with a plain number. Skip three things, each a header artifact:
# `__NR_syscalls` (the sentinel, which the header redefines per ABI),
# `__NR_arch_specific_syscall` (the start of a range, not a call -- arm64 fills
# none of it), and every number at or above 1024 (the 32-bit compat block).
# Counting them invents syscalls the kernel does not have. The 64-bit aliases
# (`#define __NR_fcntl __NR3264_fcntl`) have no plain number and are skipped
# too -- their `__NR3264_` definitions are the ones counted.
set -u
[ $# -eq 1 ] || { echo "usage: $0 unistd.h" >&2; exit 64; }
[ -f "$1" ] || { echo "no such header: $1" >&2; exit 66; }

awk '
    /^#define[ \t]+__NR_[A-Za-z0-9_]+[ \t]+[0-9]+[ \t]*$/ {
        if ($2 == "__NR_syscalls") next
        if ($2 == "__NR_arch_specific_syscall") next
        if ($3 + 0 >= 1024) next
        print $3 + 0, $2
    }
' "$1" | sort -n | awk -v file="$1" '
    { n++; num[n] = $1; name[n] = $2 }
    END {
        if (n == 0) { print file ": no syscalls found" > "/dev/stderr"; exit 1 }
        printf "%s\n  %d real syscalls, from %s (%d) to %s (%d)\n",
            file, n, name[1], num[1], name[n], num[n]
    }
'
