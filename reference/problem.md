# The problem

Android's kernel is Linux. Android's userspace is not Linux as a glibc package
understands it. An FHS tree needs both, and only one of them is available.

This page is the platform model the rest of the guide leans on: what the phone
does, what it refuses, and why a refusal is not a bug you can configure away.

Run [examples/probe.sh](../examples/probe.sh) on the phone to get this page's
numbers for your device instead of trusting the table.

The platform is one half of the story. The other half is what you build on it: a
**a glibc userland** you import, or **the host's own material** assembled from
what the phone already gives — different costs, different failure classes,
different places to live ([two kinds of tree](../tree/README.md)). This page
is the half both of them share.

## What you actually have

| | on a stock phone | evidence |
| --- | --- | --- |
| kernel | 4.4 – 6.x, `aarch64`, ext4/f2fs, full `/proc` and `/sys` | [m] four devices, [evidence](./evidence.md) |
| uid | one real uid per domain: the app's `u0_aNNN`, or `2000(shell)` over adb. No reachable 0 | [m] |
| `CAP_SYS_ADMIN` | not held → no `mount`, no `chroot`, no `pivot_root`, no `unshare` of a mount namespace | [m] |
| `CAP_NET_RAW` | not held → `ping` returns `EPERM`, raw sockets fail | [m] |
| seccomp | a filter installed by the zygote (app domain) or absent (`adb shell`, root) | [m] `Seccomp: 0` for uid 2000 |
| SELinux | enforcing; the domain decides what the uid *may* do with the files it owns | [m] `getenforce` |
| `/dev` | only nodes the domain may open; no `/dev/net/tun`, no loop devices, no FUSE for apps | [s] + [m] |
| PID 1 | Android's `init`; it cannot be replaced and will not run your tree's units | [s] |
| page size | 4 KB historically; 16 KB on some 2024+ devices | [s] |

## The three gates

A syscall from a program in your tree passes three independent gates before it
does anything. This is the single most useful model in the whole guide: it tells
you which layer can fix which failure, and which failures no layer can fix.

| gate | enforced by | failure shape | library-agnostic |
| --- | --- | --- | --- |
| **A — filter** | a seccomp filter in the process's own sandbox | a **signal** (`SIGSYS`): the process is killed, not an `errno` | yes |
| **B — capability / kernel config** | the kernel (missing capability, feature compiled out) | a normal `errno` (`EPERM`, `EINVAL`, `ENOSYS`) | yes |
| **C — mandatory access policy** | SELinux | a normal `errno` (`EPERM`) | yes |

All three act **before** libc's own code is considered. That is why patching or
rebuilding a library cannot move a program through them: the library can choose
*differently* inside its own code, but the kernel still decides afterwards.

**The asymmetry that shapes every design.** Gates B and C already return clean,
catchable errnos — indistinguishable from what an unprivileged user sees on an
ordinary Linux box, and well-written software already handles them. Gate A is
the anomaly: it does not return an `errno`, it kills the process with a signal
that portable error handling does not expect. Any *fast* path that does not run
under a supervisor loses its Gate A handling, because nothing is there to catch
the signal.

The practical corollary: an app-domain tree pays for Gate A, an `adb shell` tree
does not. `Seccomp: 0` for uid 2000 is why [the ADB host](./domains.md)
is the easiest domain on the phone — and why it is the wrong domain for a
general-purpose app.

## What a package assumes

A package carries two contracts: an installation contract (`control`, read by the
package manager) and an execution contract (`data`, enforced by the kernel, the
loader and libc). Debian's `.deb` is the worked instance — `control.tar`,
`data.tar` — and its execution contract encodes eight assumptions:

| # | assumption | where it lives | gate |
| --- | --- | --- | --- |
| 1 | files belong under `/usr /etc /var` at the root; scripts hard-code those paths | `data/`, maintainer scripts | path |
| 2 | a dynamic ELF's interpreter is the canonical loader path | `PT_INTERP` | path + B |
| 3 | the package's architecture label is what the manager expects | `control` | manager |
| 4 | the actor is uid 0 | file owners, scripts | B |
| 5 | `DT_NEEDED` resolves through the system cache and default dirs | ELF dynamic section | path |
| 6 | `#!` lines resolve against the real root | shebangs | path + B |
| 7 | the filesystem supports hardlinks and the usual primitives | `data/` entries | B |
| 8 | the kernel tolerates the syscall surface | static ELF code | A + B + C |

Assumptions 3, 1 and 6 are text and can be edited. 2 and 5 can be edited in the
file or redirected at load. 4, 7 and 8 cannot be edited at all — they have to be
answered.

The worked instance is Debian's `.deb`, and the page is about a glibc package
([scope](../README.md#the-methods-side-by-side)). The eight sentences hold
for any glibc package; a musl package answers 2 and 5 with different machinery —
another loader name, no `ld.so.cache` — so it is a different table, not a
different row.

**The ordering constraint.** The layer that pays assumptions 1–8 must exist
**before the first package is installed**, because the package's own `preinst`
runs binaries that already assume the whole world. This is why "install the tree
first, fix it later" does not work, and why `debootstrap --second-stage` is the
real test of a runtime.

## Two failure classes

- **Class A — logical.** Wrong even on a completely permissive kernel. Examples:
  `PT_INTERP` names `/lib/ld-linux-aarch64.so.1`, which does not exist at the real
  root; `postinst` calls `/usr/bin/update-alternatives`.
- **Class B — physical.** Wrong no matter how correct the paths are. Examples:
  `chown`, `setuid`, `mount`, `socket(AF_PACKET)`, `io_uring_setup`.

The method follows from the **pair** (A/B) × (editable or not), not from either
axis alone. That table is in [the methods](../methods/README.md).

## What a directory needs to be a "tree"

A Debian tree in a directory is a pile of files until these exist and work:

1. **A loader that finds the tree** without being told on the command line — the
   kernel passes no options to `PT_INTERP`, only the environment and files.
2. **Something that answers every path the kernel resolves**, including the ones
   libc computes internally (NSS, `gconv`, `ld.so.cache`).
3. **An identity layer** — `id` must say `0`, `chown` must look successful, and
   `setuid` bits must be honoured, because `passwd`, `sudo` and every maintainer
   script expect them.
4. **`/dev/null`, `/dev/zero`, `/dev/urandom`, `/dev/tty`, `/proc`, `/sys`** — the
   real ones are fine and are usually the right answer.
5. **`/etc/resolv.conf`** — Android's resolver is `netd`; there is no file at the
   real root, and glibc's resolver reads a file.
6. **A writable `/tmp` and `/var`** — inside the tree, not the phone's.
7. **`/etc/passwd`, `/etc/group`, `/etc/shadow`** with at least the uid the tree
   runs as, or `whoami`, `$HOME` and `ssh` misbehave.
8. **A supervisor** for services, because the tree has no PID 1 of its own.

Items 1–3 are the interesting ones and each has more than one solution: that is
[the methods](../methods/README.md).

## Why not just run everything as root

Because there is no root. `su` on a stock phone does not exist; Magisk is a
different project with a different threat model. "Fake root" is not a
convenience — it is the only way to satisfy assumption 4, and it works only
because almost nothing verifies privilege through the kernel. What *does*
verify it (setuid helpers actually changing euid, `mount`, `chown`) is exactly
the set of things that keep failing, and [limits](./limits.md) lists them by
symptom.

## The one thing to remember

The kernel has never heard of your tree. Every byte of progress comes from a
layer you own standing between the program and the kernel — rewriting a path,
answering a call, or interpreting an identity. Once you accept that, the choice
of method ([the methods](../methods/README.md)) is a budget question, not a mystery.
