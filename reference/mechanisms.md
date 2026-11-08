# What the kernel and the host offer

A program in a tree gets the phone's kernel, not a container's. What it may use
is decided by three things that are easy to confuse: the **kernel's version**
(which calls exist — [syscalls.md](syscalls.md)), the **platform's policy**
(SELinux, and which nodes a domain may open), and the **domain's filter** (a
signal, not an `errno` — [syscalls.md](syscalls.md#the-filters-numbers-per-device)).
This page is the second and third for the facilities a tree's program actually
reaches for.

"Since" is mainline; a vendor kernel may backport one and omit another, so the
per-phone column is what a design may rely on [s].

## Interception, for a runtime

| mechanism | since | 4.14 | 5.10 | what it is for |
| --- | --- | --- | --- | --- |
| `ptrace` + `SECCOMP_RET_TRACE` | 3.5 / 3.8 | yes | yes | the tracer: one stop per traced call |
| `SECCOMP_RET_TRAP` handled in-process | 3.5 | yes | yes | a fast path, but the handler does not survive `exec` |
| `SECCOMP_RET_USER_NOTIF` | 5.0 | **no** (`EINVAL`) | yes | a supervisor without `ptrace`; `ADDFD` (5.9) hands the program an fd |
| Syscall User Dispatch | 5.11 | no | no | a third net; neither phone has it |

The 4.14 refusal is measured on the reference device [m]; the others are read in
the kernel's interface [s]. A tree does not need any of these — they are the
[tracer](../methods/tracer.md)'s engine.

## A terminal

- **The host's PTYs, if the domain may open them.** `/dev/ptmx` and the host's
  `devpts` are a real kernel object shared with the phone; if they open and
  `TIOCGPTN`/`TIOCSPTLCK` work, then `openpty`, `posix_openpt`, termios and
  `SIGWINCH` behave as on a Debian chroot [s]. On the two reference phones
  (Android 12 and 10, shell domain) `/dev/ptmx` opens read and read-write [m];
  whether a pair then works needs a program that calls `openpty`, which is the
  open sketch in [the backlog](../recipes/backlog.md). In the app domain it is a
  probe, not an assumption [u].
- **If they do not open, there is no userspace substitute.** A `socketpair` is
  not a TTY, and a shim that fakes `isatty()` breaks the program at the next
  `tcgetattr` [s]. The honest answer is the `errno`, not a fake.
- **There is no VT layer.** No `/dev/tty1..N`, no `console`; a PTY is the
  console a tree has [s].
- **`utmp`/`wtmp`/`btmp`/`lastlog` are files in the tree**, written by the
  programs that log in and read by `who`/`last`; the setup provides the file
  and the modes (`/run/utmp` `root:utmp 0664`, `wtmp`/`btmp` `root:utmp 0660`),
  not a daemon [s].

## Shared memory

- **SysV IPC is absent from the kernel's configuration**: `shmget` answers
  `ENOSYS` on all three phones, in the shell domain as well [m]. It is not a
  policy a tree can change.
- **POSIX shared memory has no filesystem to sit in**: `/dev/shm` does not
  exist, and `/tmp` is not one on every release [m].
- **`memfd_create` works on every phone measured**, and a segment survives
  `fork` ([a recipe](../recipes/memfd-shared-segment.md)) [m]. Passing it to a
  process that did not inherit it needs `SCM_RIGHTS` over a socket, and a
  program that calls `shmget` still fails: only code you control can choose
  `memfd`.
- `FICLONE` (a reflink) is 4.5 and depends on the filesystem; untested here [u].
- `mseal`, `membarrier`, `process_madvise`, `pidfd_open`, `io_uring`: present on
  5.10 and absent or killed on 4.14 — [syscalls.md](syscalls.md) has the counts.

## What leaks

A tree is a directory, and anything the kernel reports about the machine is the
**phone's** answer, not the tree's:

| the program asks | it gets |
| --- | --- |
| `/proc/self/mounts`, `statvfs` | the phone's mounts and free space, not the tree's |
| `/proc/net/*`, netlink | the host's interfaces, routes and sockets (where the domain allows netlink) |
| `/dev` | the phone's device nodes, through the domain's permissions ([devices](devices.md)) |
| `/sys` | the vendor's kernel and devices |

No path rule changes this, because the answer never goes through a path. A
program that needs the tree's view of these needs a synthesized file, which is a
runtime's job ([loader](../methods/loader.md), [tracer](../methods/tracer.md)).
The domain decides part of it: route netlink is refused in the app domain and
allowed in the shell, per the project's notes [u].

## The parts a fast path cannot beat

- **vDSO.** `clock_gettime` and `getcpu` never enter the kernel; no trap, no
  filter, nothing a runtime can improve [s].
- **`inotify`** (2.6.13) is the way to know a cached answer moved, instead of a
  coarse generation counter [s].

## Getting your device's numbers

[examples/probe.sh](../examples/probe.sh) covers the domain and the nodes it
tests; a PTY needs its own probe (`open("/dev/ptmx")`, `ioctl(TIOCGPTN)`), and
the filter's set needs the census ([syscalls.md](syscalls.md#getting-your-own-numbers)).

## Caveats

- **Per device, per domain, per release.** A facility that opens in the shell
  domain can be refused in the app domain, and a vendor kernel may differ from
  mainline on the "since" column.
- **A mechanism is usable only where the kernel has it and the policy allows
  it**; the two failures look alike from a program (`ENOSYS` vs `EPERM`) and the
  catalogue separates them ([limits](limits.md)).
