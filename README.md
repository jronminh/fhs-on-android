# Running an FHS tree on Android

How to run a real Linux root filesystem — a Debian or Ubuntu `arm64` tree laid
out per the FHS — on a **stock, non-rooted** Android phone.

This is a guide, not a product and not a wrapper around one. It contains the
map of the problem, the space of methods, one working recipe, the failure
catalogue, and the evidence behind every claim.

- Ten minutes, a tree that boots: [docs/03-build-a-tree.md](docs/03-build-a-tree.md)
- It broke, here is why: [docs/05-limits.md](docs/05-limits.md)
- Which method should I pick: [docs/02-methods.md](docs/02-methods.md)
- What the platform actually refuses: [docs/01-the-problem.md](docs/01-the-problem.md)

## The short version

**You cannot mount, so you must map.**

A stock phone gives an app no `CAP_SYS_ADMIN`: `chroot`, `mount` and `unshare`
are refused. So the tree is not a root filesystem at all — it is a directory
the kernel has never heard of. Every absolute path inside it (`/usr/lib`,
`/etc/passwd`, `/lib/ld-linux-aarch64.so.1`) is wrong at the real root, and the
only uid you have is the one you were started with.

Nothing in the kernel will fix that for you. Whatever you build has to sit in
the path of every access — or rewrite the access before it happens. That is the
whole design problem, and the rest of this guide is about doing it with the
least lying.

## Three bars for "it works"

Most "Linux on Android" instructions stop at "*a shell appears*". This guide
uses three bars, in order, because each one exposes a different layer:

| bar | what it proves | how to check |
| --- | --- | --- |
| **1. It boots** | the loader, the shim and the identity layer agree | `id`, `ls -l /usr/lib`, `dpkg -l \| head` |
| **2. Package management works** | maintainer scripts, hooks and `apt`'s assumptions survive the relocation | `apt-get update && apt-get install figlet` |
| **3. Real work runs** | the syscall surface is wide enough for a compiler, `git`, Python | build Lua, `git init/add/commit`, `python3 -c 'import os; list(os.walk("/usr"))'` |

A tree that passes 1 and fails 2 is usually a path problem. A tree that passes 2
and fails 3 is usually a kernel-refusal problem (Gate A/B/C, see
[01](docs/01-the-problem.md#the-three-gates)).

## What Android gives you, and what it takes away

| | |
| --- | --- |
| **Gives** | a Linux kernel (4.4–6.x), `arm64`, ext4/f2fs, normal ELF loading, `/proc`, `/sys`, a working TCP/IP stack, hardware that is faster than most desktops from 2015 |
| **Takes away** | `chroot`, `mount`, `unshare` (no `CAP_SYS_ADMIN`); uid 0 (no reachable root); `setuid` bits (present, inert); a full syscall surface (a seccomp filter kills instead of returning `errno`); `/dev` nodes beyond what the app may open; an `init` you can replace |

Full detail, with the three gates and the eight assumptions a Debian package
encodes: [docs/01-the-problem.md](docs/01-the-problem.md).

## The methods, compressed

| method | root | paths resolved by | cost | FHS tree |
| --- | --- | --- | --- | --- |
| `chroot` + bind mounts | yes | the kernel | none | yes |
| proot (ptrace translation) | no | a tracer, every path syscall | a stop per syscall | yes |
| user namespaces | no | the kernel, inside a namespace | none | if the kernel allows it |
| `LD_PRELOAD` shim only | no | libc symbols | near-native | partial |
| loader + shim + tracer (hybrid) | no | rewritten `PT_INTERP`, symbols, tracer | near-native | yes |
| glibc bundle / `glibc-runner` | no | a loader that pivots its own prefix | near-native | no — individual binaries |

Trade-offs, coverage gaps and what each one silently breaks:
[docs/02-methods.md](docs/02-methods.md).

## Reading the claims

Every non-obvious statement in this repository is labelled:

- **[m]** — measured, on one of the devices in [docs/08-evidence.md](docs/08-evidence.md), on a named date.
- **[s]** — read in a specification or in source (AOSP, glibc, the kernel).
- **[u]** — unverified assumption, or a report from elsewhere that this guide has not reproduced.

There are no unlabelled performance numbers in this repository. If a sentence
says "faster", it says faster than what, on which phone.

## Status

2026-11, pre-alpha, one maintainer. The recipe in
[docs/03](docs/03-build-a-tree.md) is the one the measurements came from and is
maintained with [deb-native](https://github.com/jronminh/deb-native) (GPL-3.0),
which is the reference implementation of the hybrid method. Nothing here depends
on that project existing: [docs/03](docs/03-build-a-tree.md) also gives the
by-hand path, and [docs/07](docs/07-prior-art.md) lists the other
implementations.

Corrections with a device and a date are the most useful kind of contribution —
see [CONTRIBUTING.md](CONTRIBUTING.md).

## Contents

| | |
| --- | --- |
| [01](docs/01-the-problem.md) | the platform: what is missing, the three gates, the eight assumptions |
| [02](docs/02-methods.md) | the method space, with trade-offs and a decision tree |
| [03](docs/03-build-a-tree.md) | build one: proot in ten minutes, or a native tree by hand |
| [04](docs/04-hosts.md) | Termux, a custom APK, `adb shell`, root — what each domain gives |
| [05](docs/05-limits.md) | failure catalogue: symptom → cause → what to do |
| [06](docs/06-measure.md) | how to measure honestly on a phone |
| [07](docs/07-prior-art.md) | proot, glibc-runner, Linux Deploy, WSL1, Waydroid, gVisor |
| [08](docs/08-evidence.md) | devices, dates, and which claims rest on what |
| [examples/probe.sh](examples/probe.sh) | one read-only script that answers "what does this phone actually allow?" |

## License

Text: CC BY 4.0. Scripts: MIT. See [LICENSE](LICENSE).
