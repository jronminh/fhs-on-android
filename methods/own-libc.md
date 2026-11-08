# Own the libc

Isolation **1**. Two ways to put the tree's policy inside libc itself, and one
of them is half-alive: the syscall half was dropped, the path half still ships.

## What it buys

- **The change reaches every process**, including a static binary that no
  preload reaches and no shim sees.
- **No stop per call**: the answer happens where libc makes the call, not at the
  syscall boundary.
- **The policy is yours to change.** A tracer can reinterpret a call; a libc you
  own can decide differently.

## What it costs

- **A CVE in glibc becomes yours**; upstream releases must be rebuilt and
  retested. A fork you stop updating is worse than no fork.
- **The ABI floor binds the runtime**: a shim built against a newer glibc than
  the tree carries fails to load with a version error, so the runtime must record
  which libc it was built against.
- **The bootstrap needs a Linux host and hours of `gcc`** — a one-time offline
  step whose output is an image.
- **Every patch must be forward-ported forever.**

## Two forms, and what happened to each

### Patch a distribution's libc

Two different patches lived here, and they ended differently:

- **The syscall answers.** A glibc built for Android with the denied syscalls
  (`rseq`, `clone3`) answered inside libc. It was trimmed hunk by hunk, and today
  nothing of it is applied: the tree takes the distribution's stock `libc6`, and
  those syscalls are answered at the [syscall boundary](tracer.md) instead [s].
- **The path and name-service patches.** Prefixed paths, Android's passwd and
  group ids, the absence of SysV IPC, the loader's `LD_PRELOAD` hygiene. These
  still ship — as **ten files** of the distribution's `libc6`/`libc-bin`, not as
  a fork: [patched libc](patched-libc.md) [u].

A patch is still right where the change must be **inside every process**. What
separated the two is what the change was about: one had to answer calls that the
kernel or a filter refused, and that answer belongs at the boundary; the other
has to change what the userland calls *itself*, and that has to be in libc.

### Build the tree's own libc

The other form, and valid: build the tree's glibc from source (LFS's toolchain
bootstrap; the road, its neighbours and its cost are in
[glibc build](../reference/glibc-build.md)). What it buys:

- the denied syscalls answered where libc makes them — your policy, no stop;
- only the `locale`, `gconv` and NSS modules the tree needs;
- a loader path and run-time prefix that are **yours**, so the tree moves without
  rewriting every `PT_INTERP` in it;
- no builder's fingerprint (`Debian GLIBC 2.41`) in every binary;
- and, when something is wrong, the ability to *change* the layer the program is
  written against — a tracer can only reinterpret.

## Example

Owning the libc changes one thing the runtime can observe: the loader a program
names. [examples/which-loader.sh](../examples/which-loader.sh) prints it, and
whether it resolves inside the tree - the same check for a distribution libc and
for one you built:

```sh
./which-loader.sh TREE/bin/hello TREE
# interp: /lib/ld-linux-aarch64.so.1
# resolves: TREE/lib/ld-linux-aarch64.so.1
```

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `version 'GLIBC_2.38' not found` loading a shim or program | the binary was built against a newer libc than the tree carries | rebuild against the tree's libc, or ship the newer one |
| a program works with the stock libc and not the fork | the patch changed behaviour, not just a refusal | diff the patch against upstream for that path |
| `setlocale: LC_ALL: cannot change locale` | the trimmed libc has no locales | generate or ship `C.UTF-8`, and keep `LANG=C.UTF-8` |
| the fork stops building after an upstream release | forward-port debt | budget it: the cost does not stop when you stop building |
| a swapped tree aborts every program at start | a host `LD_PRELOAD` reached a loader without the patch's hunk | see [patched libc](patched-libc.md#how-it-fails) |

## By domain

The libc is the same in all three domains; what changes is whether the app's
filter kills a call before the libc's own policy applies
([reference/domains.md](../reference/domains.md)).

## Evidence

The fork was built, trimmed and then dropped, and the reason is stated above
[s]; what the build-from-source route forces on the runtime - the loader taken
from `PT_INTERP`, the cache taken from the tree - is [s]. It has not been built
here [u]. The ten-file set, and the fact that it still ships, are the project's
own records, not re-run in this guide [u].
