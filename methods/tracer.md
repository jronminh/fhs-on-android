# The tracer

Isolation **3**. A `ptrace` tracer under a seccomp filter sees every syscall the
program makes and can rewrite paths, answer identity, and refuse what the kernel
would not. It has the widest coverage of the surfaces here: it catches static binaries, raw
`syscall()`, and the reads libc performs inside itself.

## What it buys

- **Coverage nothing else has**: static binaries and raw syscalls included; the
  full list of readers is [every reader of a coordinate](../reference/surfaces.md).
- **No per-file work**: the same tracer runs a tree it has never seen.
- **One place for the kernel's refusals**: a trap can become `ENOSYS` or `EPERM`
  so software can fall back instead of being killed.

## What it costs

- **A stop per traced call**: about **19 us** polling and **~150 us** sleeping,
  against a filter tax of about **80 ns** on every call [m]. Metadata-heavy work
  pays most: `find`, `apt`, `git status`.
- **It must be the ancestor of every process** - the filter has to be installed
  before the first instruction, or a program escapes by being started normally.
- **It cannot be nested**: a second tracer cannot attach, so "just `strace` it" is
  not available while the tree runs.

## What the kernel offers here

| mechanism | on the probed devices |
| --- | --- |
| `ptrace` + `SECCOMP_RET_TRACE` | yes - what the runtime uses |
| `SECCOMP_RET_TRAP` (`SIGSYS` in-process) | yes, and it is what an app-domain filter does to *you* |
| `SECCOMP_RET_USER_NOTIF` (a supervisor on a listener fd) | no: `EINVAL` on kernel 4.14 [m] |
| Syscall User Dispatch (5.11+) | no: `EINVAL` on 4.14; the newer device is 5.10 |

## Proot: someone else's implementation

`proot` implements this same surface - `ptrace`, path rewriting on the arguments, some
identity answers - with no privilege, which is why `proot-distro` is the standard
"Linux on Android" answer. The runtime before the rewrite was a PRoot fork (tag
`legacy-dn-monitor`). It buys the fewest coverage holes; it costs a stop per traced
call on exactly the work people notice. This guide has not measured proot itself.

## Example

Before building a tracer, see what it would be paid: every syscall a tracer stops
is a stop. [examples/count-stops.sh](../examples/count-stops.sh) counts them for a
workload on a Linux host:

```sh
strace -f -c -q "$@" 2>&1 | tail -n 12
```

The same workload under a tracer pays a stop for each row that is in the filter -
which is why the filter is number-first, and why the design goal is fewer stops.

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| the process dies with `Bad system call` | a syscall the app's filter traps (`TRAP` outranks `ERRNO`, so no errno is returned) | a supervisor installed from the first instruction, or a domain without the filter |
| `ptrace: Operation not permitted` | a second tracer tried to attach | do not trace a traced tree; use the runtime's own counters |
| the tree is slow only on `find`/`apt` | one stop per metadata call | it is the method's cost, not a bug ([measure](../reference/measure.md)) |
| a program escapes the mapping after `exec` | the tracer was not re-armed across the exec | check the exec handoff |

## By domain

Gate A is the **app** domain's; in **shell** there is no filter at all
([reference/domains.md](../reference/domains.md)). A tracer that does not survive
`SIGSYS` is unusable in an app.

## Evidence

The stop costs, the filter tax and the two unavailable mechanisms are measured on
the reference device [m]; the identity half is in [identity](identity.md).

## Tried, not kept - and what it cost

- **An in-process catcher**: install the filter with `RET_TRAP` and handle `SIGSYS`
  inside the program. The handler does not survive `exec`, and the failure is a dead
  process with no message.
