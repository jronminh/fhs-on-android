# Own the libc

Isolation **1**. Two different things live here, and this project keeps only one
of them — for a maintenance reason, not a correctness one.

## Patch a distribution's libc

There was a fork: a glibc built for Android with the denied syscalls (`rseq`,
`clone3`) answered inside libc. It was trimmed hunk by hunk, and today nothing of
it is applied: the tree takes Debian's stock `libc6`, and those syscalls are
answered at the [syscall boundary](tracer.md) instead [s].

What it cost this project: a second owner of behaviour the tracer already owned;
a re-cut for every glibc version; answers that are the same ones the boundary
gives, one layer further in, where they cannot be seen or disproved. A patch is
still right when you need the change **inside every process**, including static
ones, without a supervisor.

## Build the tree's own libc

The other form, and valid: build the tree's glibc from source (LFS's toolchain
bootstrap). What it buys:

- the denied syscalls answered where libc makes them — your policy, no stop;
- only the `locale`, `gconv` and NSS modules the tree needs;
- a loader path and run-time prefix that are **yours**, so the tree moves without
  rewriting every `PT_INTERP` in it;
- no builder's fingerprint (`Debian GLIBC 2.41`) in every binary;
- and, when something is wrong, the ability to *change* the layer the program is
  written against — a tracer can only reinterpret.

## What it costs — all maintenance

- **A CVE in glibc becomes yours**; upstream releases must be rebuilt and
  retested. A fork you stop updating is worse than no fork.
- **The ABI floor binds the runtime**: a shim built against a newer glibc than the
  tree carries fails to load with a version error, so the runtime must record
  which libc it was built against.
- **The bootstrap needs a Linux host and hours of `gcc`** — a one-time offline
  step whose output is an image.
- **Every patch must be forward-ported forever.**

## Example

Owning the libc changes one thing the runtime can observe: the loader a program
names. [examples/which-loader.sh](../examples/which-loader.sh) prints it, and whether
it resolves inside the tree - the same check for a distribution libc and for one
you built:

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

## By domain

The libc is the same in all three domains; what changes is whether the app's
filter kills a call before the libc's own policy applies
([reference/domains.md](../reference/domains.md)).

## Evidence

The fork was built, trimmed and then dropped, and the reason is stated above [s];
what the build-from-source route forces on the runtime - the loader taken from
`PT_INTERP`, the cache taken from the tree - is [s]. It has not been built here
[u].
