# What is in this repository, and what proves it

The guide is self-contained: every method page carries an example that lives in
`examples/`, and nothing here requires another repository to read or to check.

This page is the index: example -> what it demonstrates -> how to check it.

## The examples

| example | demonstrates | check it |
| --- | --- | --- |
| [cmd.sh](../examples/cmd.sh) | a command is a file; `status`/`check`/`apply`, with `check` answering a question | run it on a phone; `check` exits non-zero and prints `diff ...` when the state is wrong |
| [which-loader.sh](../examples/which-loader.sh) | static vs dynamic, and whether the named loader exists in the tree | `which-loader.sh /system/bin/sh`, then a program from the tree |
| [elf-interp.sh](../examples/elf-interp.sh) | the one-field edit, idempotent, skipping what has no `PT_INTERP` | `--dry-run` on a copy of a tree |
| [shim-open.c](../examples/shim-open.c) | a path shim in one symbol, and the blind spots named in its header | build it and run a dynamic program with `LD_PRELOAD` |
| [identity.c](../examples/identity.c) | identity answered at the symbol layer, and the checks that still fail | `LD_PRELOAD` it and run `id` |
| [isolate-check.sh](../examples/isolate-check.sh) | the isolation the platform allows is two commands away | run it in each domain |
| [libc-swap.sh](../examples/libc-swap.sh) | the ten-file swap as a stash plus an idempotent restore, with the manifest beside it | point it at a tree and a patched set; it prints `stashed: 10 files` and `restored: 10 files` |
| [syscall-count.sh](../examples/syscall-count.sh) | the arm64 syscall count per kernel, from the kernel's own header | run it on `unistd.h` fetched at `v4.14`, `v5.10`, `v6.1`, `v6.12`: 266, 306, 316, 328 |
| [build-bionic.sh](../examples/build-bionic.sh) | owning the build, and finding the paths the tree must then teach | `CC=` an NDK clang, then run it on a source file |
| [count-stops.sh](../examples/count-stops.sh) | what a tracer would be paid: the syscalls a workload makes | run it on a Linux host with `strace` |
| [probe.sh](../examples/probe.sh) | what the phone itself allows: gates, capabilities, nodes | run it on the phone, read-only |

## Measured, 2026-11-08

Three of the files were run on three phones (Android 10, 12, 15; `uid=2000`,
`Seccomp: 0`) [m]:

- `which-loader.sh` - on Android 12 and 15: `interp: /system/bin/linker64`,
  `resolves: /system/bin/linker64`; with a wrong tree: `MISSING: ... (execve answers ENOENT)`.
  On Android 10 there is no `readelf`, and it exits 69 instead of guessing "static".
- `isolate-check.sh` - `chroot: refused (125)` and `userns: refused (1)` on all three.
- `cmd.sh` - `mode=shell`, `boot=1`, `functions=rndis` where tethering is on.

The rest need tools the phones do not ship, and each says so instead of failing
silently: `patchelf` ([elf-interp.sh](../examples/elf-interp.sh)), a compiler
([build-bionic.sh](../examples/build-bionic.sh) and the two C files), `strace`
([count-stops.sh](../examples/count-stops.sh)).

## Measured with a glibc tree, 2026-11-08

`glibc-chroot.sh` (needs a glibc userland to take three files from) was run on the
rooted phone [m]: a **2.1 MB** tree — `dash`, `libc.so.6`, `ld-linux-aarch64.so.1` —
entered with `chroot`; inside, the loader printed
`Debian GLIBC 2.41-12+deb13u4`, `dash` computed, `/proc/version` read the phone's
kernel, and `/system` was absent. The three states it walks through:

```
A) no loader        -> chroot: exec /bin/sh: No such file or directory
B) loader, 0644     -> chroot: exec /bin/sh: Permission denied
C) loader, 0755     -> runs; Debian GLIBC 2.41 inside
```

## Measured on a rooted phone, 2026-11-08

`root-chroot.sh` was run on a Magisk phone (Android 15, kernel 5.4.242) [m]: a
1.7 MB tree of 359 busybox applets, `proc`/`sys`/`dev` bound, entered with `chroot`.
Inside: `uid=0`, the phone's kernel, `/proc` readable, and `/system` absent - the
isolation bought and the reach paid. The first attempt failed with
`chroot: exec /bin/sh: No such file or directory`, because `busybox --install -s`
writes absolute links; relative ones fixed it. That row is in
[chroot.md](../methods/chroot.md#how-it-fails).

## Measured on a Linux host, 2026-11-08

Four more were run on a x86-64 Debian host, without building a tree, because the
mechanism does not need one [m]:

- `elf-interp.sh --dry-run` on a copy of a dynamic binary printed
  `would set: ...  was: /lib64/ld-linux-x86-64.so.2  now: <tree>/lib/...`, and skipped a
  static binary because it has no `PT_INTERP`.
- `which-loader.sh`: `/lib64/ld-linux-x86-64.so.2` for a dynamic program,
  `static: no interpreter` for one built with `-static`.
- `identity.c`: `id -u` prints 1000, and 0 under `LD_PRELOAD` - while a real
  `chown` still fails, because coreutils calls `fchownat`, not `chown`: a symbol-level
  answer covers only the symbols the program uses.
- `shim-open.c`: `cat /etc/hostname` under `TREE` prints the tree's file, and a
  **static** probe prints the host's - the blind spot, shown by the run.

## Where the numbers come from

The measurements in this guide are labelled [m] and were taken on named devices
on named dates ([evidence](evidence.md)). The failures come from runs that broke,
and they are written as the shape symptom -> cause -> next check, not as stories.
Where a claim has neither a run nor a specification behind it, it is marked [u] and
the page says so.

## What is not here

Everything marked `[u]` has no example: a tree with its own glibc, `chroot` and
user namespaces on Android, a virtual machine, and a fused loader. [chroot.md](../methods/chroot.md)
is written from the platform's rules, and says as much.
