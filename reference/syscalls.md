# What the kernel and the filter refuse

Two independent refusals stand between a program and the kernel, and they differ
in kind: the filter **kills** (`SIGSYS`), the kernel **answers** (`ENOSYS`,
`EPERM`). A tree can fix neither; a runtime at the boundary can answer the first,
and can only pass the second through. This page is the map behind
[the three gates](problem.md#the-three-gates) and the symptoms in
[the failure catalogue](limits.md).

## One arm64 table

arm64 uses one generic syscall table: a number means the same call on every
arm64 kernel, and kernels only **add** — no number is reused [s]. So a
distribution's headers describe calls the phone may not have:

| kernel | real syscalls |
| --- | --- |
| 4.14 (the reference S10e) | 266 |
| 5.10 (Android 16) | 306 |
| 6.1 | 316 |
| 6.6 | 318 |
| 6.12 = Debian 13's headers | 328 |

Between 4.14 and Debian's 6.12 headers there are **62 calls the phone does not
have**: `clone3`, `rseq`, `openat2`, `faccessat2`, `fchmodat2`, `io_uring_*`,
`futex_waitv`, `landlock_*`, `mseal`, the `*_time64` family, and others [s]. For
each, the phone answers `ENOSYS`, and glibc falls back — for most of them. What
it does not fall back from is a failure the catalogue names.

The list is reproducible: [examples/syscall-count.sh](../examples/syscall-count.sh)
reads `include/uapi/asm-generic/unistd.h` at a tag, keeps the plain
`#define __NR_name N` lines, and drops three header artifacts — the
`__NR_syscalls` sentinel, `__NR_arch_specific_syscall` (a range start, not a
call: arm64 fills none of it), and the `nr >= 1024` compat block [s]. Without
the second skip the count is 267, not 266; that is why the rule is written down
rather than assumed. Run on the four tags, the script gives the table above
exactly.

## The filter's numbers, per device

In the **app** domain the zygote's filter decides first, and its refusals arrive
as a signal. The project's census of 2026-10-13/16 counted every number from 0
to 470 (14 skipped) on two phones [m]:

| | Android 12, 4.14 (S10e) | Android 16, 5.10 (S23 FE) |
| --- | --- | --- |
| allowed in the app | 201 | 217 |
| killed with `SIGSYS` | 256 | 240 |
| of the killed, the kernel implements the call | **32** | **42** |
| of the killed, the kernel lacks the call | 224 | 198 |

The 32 and the 42 are the *real denials* — calls the kernel has and the platform
withholds. The 224 and 198 are calls the kernel never had: they would answer
`ENOSYS` even without a filter.

## The 32 real denials, on 4.14

| group | calls | what they mean for a program |
| --- | --- | --- |
| 1 | `accept` | the call is substituted (`accept4`) or the program sees the signal |
| 8 | `setuid` `setgid` `setreuid` `setregid` `setresgid` `setfsuid` `setfsgid` `setgroups` | identity: the syscall cannot succeed in this domain, whatever a shim says |
| 17 | `mount` `umount2` `chroot` `swapon` `swapoff` `clock_settime` `settimeofday` `adjtimex` `clock_adjtime` `sethostname` `setdomainname` `syslog` `init_module` `delete_module` `finit_module` `lookup_dcookie` `bpf` | the machine's admin surface: no tree reaches it |
| 6 | `set_robust_list` `get_robust_list` `remap_file_pages` `add_key` `request_key` `keyctl` | answered `ENOSYS` by a runtime, because nothing needs them to succeed |

`getuid`, `geteuid`, `getgid`, `getegid`, `getresuid` and `getresgid` are **not**
denied — they are allowed, and a runtime may emulate them in process.

Android 16 shows 42 = 32 − `bpf` + 11: `bpf` moves to the kernel, where an
unprivileged caller gets `EPERM` anyway, and eleven newer calls are added to the
killed set (`io_uring_*`, the new mount API, `kcmp`, `io_pgetevents`). Six calls
newly become *allowed* — `clone3`, `close_range`, `openat2`, `faccessat2`,
`fchmodat2`, `epoll_pwait2` — which shows that "allowed" means "the platform
does not kill it", not "the kernel serves it": on 5.10, `epoll_pwait2` still
answers `ENOSYS` and `openat2`'s path still has to be translated [m].

## What that means for a tree

- **The 17 are the platform's, not the tree's.** No path, no libc and no identity
  layer gets `mount` or `chroot` back; a program that needs them needs root
  ([the isolation scale](../README.md#the-isolation-scale), level 4).
- **The 8 are why identity is constructed** ([identity](../methods/identity.md)):
  the syscall cannot succeed, so the only answer is one that a program cannot
  verify.
- **The 224 are not policy.** They are the kernel's age; glibc's fallbacks are
  what a tree relies on, and a program that probes a newer call must handle
  `ENOSYS`.
- **Nothing in the tree changes either list.** The filter's answer is a signal
  because `TRAP` outranks `TRACE`; only a supervisor installed before the first
  instruction can catch it ([tracer](../methods/tracer.md)).

## Where each refusal is answered

| refusal | answered by | page |
| --- | --- | --- |
| the filter's `SIGSYS` (app domain) | a supervisor from the first instruction, or a domain without a filter | [tracer](../methods/tracer.md), [domains](domains.md) |
| a missing syscall (`ENOSYS`) | glibc's fallback, or a substitution at the boundary | [tracer](../methods/tracer.md), [limits](limits.md) |
| a capability or policy refusal (`EPERM`) | root, or a design that does not ask | [problem](problem.md), [limits](limits.md) |

## Getting your own numbers

[examples/probe.sh](../examples/probe.sh) answers the domain questions — `id`,
`Seccomp`, `CapEff`, and whether `chroot` and `unshare` work. The filter's full
number set needs a census: one `syscall(n)` per number, in the domain you care
about, recording `ok` / `EPERM` / `ENOSYS` / `SIGSYS`. The project's census is a
C program of that shape; this guide does not ship it [u].

## Caveats

- **Per device and per kernel.** The allowed/killed split follows the platform's
  policy, which is a release's decision, and the kernel's table, which is a
  version's. Neither transfers to another phone unmeasured.
- **The census covers 0..470, 14 numbers skipped**; a number above that range is
  outside it.
- **A `pass` on one device can be a refusal on another**: `bpf` is the example
  above, and `openat2` is allowed on 16 while its path still needs translating.
- **The census is the project's, not this guide's**; it was not re-run here [u].
