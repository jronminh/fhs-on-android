# Running an FHS tree on Android

A **tree** is a directory with a stable layout — `bin lib etc var` — that makes a
stock, non-rooted (or rooted) Android phone behave like a Linux box. This
repository is the map of how to build one, what the platform will and will not
allow, and which parts of the answer change when the phone is not yours to press
buttons on.

It is a guide, not a product and not a wrapper around one.

## The short version

**A tree is a layout the kernel has never heard of.**

There is no `CAP_SYS_ADMIN` on a stock phone, so `chroot`, `mount` and `unshare`
are refused; the only uid you have is the one you were started with. What
follows is not one problem but three, and they are usually confused:

1. **which kind of tree** — a foreign userland you import, or one you build from
   what the host already gives you ([two kinds of tree](docs/two-kinds-of-tree.md));
2. **which path strategy** — four ways to make a program find the tree, from
   emulating `/` to teaching the program where it lives
   ([the four strategies](docs/two-kinds-of-tree.md#the-four-path-strategies));
3. **where it lives** — and therefore whether it survives a reboot, an app
   update, or a factory reset ([root](docs/root.md#the-durability-ladder)).

Root is not a fourth question; it changes the answers to all three. So do the
host (app, `adb shell`, root) and the state rules below.

## Two kinds of tree

| | **foreign tree (A)** | **poor-host tree (B)** |
| --- | --- | --- |
| what it is | a userland the phone lacks: Debian/glibc, Alpine/musl | a layout built from `sh` + toybox (+ one busybox) and your scripts |
| buys | `apt`, compilers, unmodified software | native speed, no loader problem, a floor as old as Android 6, and **places to live** a foreign tree cannot use |
| costs | the whole emulation of `/` | you write everything; no package manager |
| recipe | [build a foreign tree](docs/foreign-tree.md) | [build a poor-host tree](docs/poor-host-tree.md) |

They compose: the durable tree can start the foreign one, and a cluster node or
a router is exactly that arrangement.

## Four bars

| bar | what it proves | how to check |
| --- | --- | --- |
| **1. It boots** | the loader, the shim and the identity layer agree | `id`, `ls -l /usr/lib`, `dpkg -l \| head` |
| **2. Package management works** | maintainer scripts, hooks and `apt`'s assumptions survive the relocation | `apt-get update && apt-get install figlet` |
| **3. Real work runs** | the syscall surface is wide enough for a compiler, `git`, Python | build Lua, `git init/add/commit`, `python3 -c 'import os; list(os.walk("/usr"))'` |
| **4. It comes back** | the tree is a *device*, not a session | simulate a reset: remove its state, reboot, touch nothing ([root](docs/root.md#the-boot-image-frame)) |

A tree that passes 1 and fails 2 has a path problem. A tree that passes 2 and
fails 3 has a kernel-refusal problem. A tree that passes 3 and fails 4 has not
decided where it lives.

## What Android gives you, and what it takes away

| | |
| --- | --- |
| **Gives** | a Linux kernel (4.4–6.x), `arm64`, ext4/f2fs, normal ELF loading, `/proc`, `/sys`, TCP/IP, hardware faster than a 2015 desktop |
| **Takes away** | `chroot`, `mount`, `unshare` (no `CAP_SYS_ADMIN`); uid 0; real `setuid`; a full syscall surface (an app-domain seccomp filter *kills*, it does not return `errno`); `/dev` nodes beyond what the domain may open; an `init` you can replace |

Detail, including the three gates and the eight assumptions a `.deb` encodes:
[the problem](docs/the-problem.md).

## Hosts decide more than methods

| host | uid | app seccomp (Gate A) | `execve` of the tree | survives a reset | fits |
| --- | --- | --- | --- | --- | --- |
| Termux | app | yes | only at `targetSdk` ≤ 28 | no | building, experimenting |
| custom APK | app | yes | needs userland exec at `targetSdk` ≥ 29 | no | a product for other people |
| `adb shell` | `2000` | **no** (`Seccomp: 0`) | yes | no | headless, servers, measuring |
| root | 0 | no | yes | **yes, from the boot image** | devices you own and must keep alive |

[hosts](docs/hosts.md) · [root](docs/root.md).

## Reading paths

- "I want a working tree in ten minutes" → [a foreign tree](docs/foreign-tree.md#recipe-a--proot-distro-ten-minutes)
- "I want to understand why it breaks" → [the problem](docs/the-problem.md), then [limits](docs/limits.md)
- "I want a tree that survives a factory reset" → [two kinds](docs/two-kinds-of-tree.md) → [a poor-host tree](docs/poor-host-tree.md) → [root](docs/root.md)
- "Which of these projects should I use?" → [prior art](docs/prior-art.md)
- "What does *this* phone actually allow?" → [examples/probe.sh](examples/probe.sh)

## Reading the claims

Every non-obvious statement is labelled:

- **[m]** — measured on one of the devices in [evidence](docs/evidence.md), on a named date;
- **[s]** — read in a specification or in source (AOSP, glibc, the kernel);
- **[u]** — unverified assumption, or a report from elsewhere that this guide has not reproduced.

There are no unlabelled performance numbers. If a sentence says "faster", it
says faster than what, on which phone.

## Status

2026-11, pre-alpha, one maintainer. The measurements come from three devices
across Android 10, 12 and 15, and from two trees that run in production on them:
a durable poor-host tree on a rooted phone, and a foreign tree on a stock one.
Where the underlying work is public it is linked:
[deb-native](https://github.com/jronminh/deb-native) (runtime, GPL-3.0), the
reference implementation of the hybrid method. Nothing here depends on that
project existing: [a foreign tree](docs/foreign-tree.md) gives the by-hand path,
and [prior art](docs/prior-art.md) lists the alternatives.

Corrections with a device and a date are the most useful kind of contribution —
see [CONTRIBUTING.md](CONTRIBUTING.md).

## Contents

| | |
| --- | --- |
| [the problem](docs/the-problem.md) | what is missing; the three gates; the eight assumptions |
| [two kinds of tree](docs/two-kinds-of-tree.md) | foreign vs poor-host; the four path strategies; the state rule |
| [methods](docs/methods.md) | the method space (M0–M10), trade-offs, a decision tree |
| [a foreign tree](docs/foreign-tree.md) | proot in ten minutes, or a native tree by hand |
| [a poor-host tree](docs/poor-host-tree.md) | busybox first, services, the web face, deploy, what broke |
| [root](docs/root.md) | what it buys, what it costs, the durability ladder, the boot-image frame |
| [hosts](docs/hosts.md) | Termux, APK, `adb shell`, root — what each domain gives |
| [limits](docs/limits.md) | failure catalogue: symptom → cause → what to do |
| [measure](docs/measure.md) | how to measure honestly on a phone |
| [prior art](docs/prior-art.md) | proot, glibc-runner, Linux Deploy, WSL1, Waydroid, gVisor |
| [evidence](docs/evidence.md) | devices, dates, and which claims rest on what |
| [examples/probe.sh](examples/probe.sh) | one read-only script that answers "what does this phone actually allow?" |

## License

Text: CC BY 4.0. Scripts: MIT. See [LICENSE](LICENSE).
