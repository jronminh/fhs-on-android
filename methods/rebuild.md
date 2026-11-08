# Rebuild the program

Isolation **0–1**. Instead of translating at run time, own the build: compile the
program against a libc that exists on the phone, and make its own paths point
into the tree. Nothing stands between the program and Android afterwards, which
is why this is the least expensive method that reaches real programs.

## What it buys

- **Level 0 for the program itself**: no shim, no tracer, no stop, no blind spot.
- **It reaches what no run-time layer can**: a static binary's internal paths,
  and a program that calls `syscall()` directly.
- **It produces a binary that belongs to the phone**, so a future Android update
  is a rebuild, not a runtime regression.

## What it costs

- **You need the source.** A prebuilt binary falls back to
  [patch](patch-package.md) or a [wrapper](loader.md).
- **One patch per program**, and the patch has to follow upstream on every
  release.
- **The tree is the root only for the programs that were taught**: anything not
  taught still sees Android's filesystem.

## Two targets

- **bionic** — build with the NDK, as the platform builds its own tools. The
  reference example is a small client binary: about 8 KB, because a *static
  glibc* client does not survive Android's filter — the kernel kills it with
  `SIGSYS` [s].
- **the tree's own glibc** — build inside the [glibc supply](../tree/glibc.md), so
  the binary links the tree's libraries and names the tree's loader.

## Teach it where it lives

Every absolute path the program owns becomes a path in the tree — home, host
keys, the passwd lookup, and `PATH`:

```c
/* before */  snprintf(home, sizeof home, "/root");
/* after  */  snprintf(home, sizeof home, "%s/home", tree_root());
```

On the reference device a static `dropbear` became part of a running tree this way:
one patch, four paths, no privilege, full speed [m].

## Example

[examples/build-bionic.sh](../examples/build-bionic.sh) does the two steps the method
is made of: compile against the phone's own libc, then list the absolute paths the
tree still has to own.

```sh
"$CC" -O2 -Wall -o "$out" "$src"
strings "$out" | grep '^/[a-z]' | sort -u | head -n 20
```

The second line is the teaching step: what it prints is the list of paths to
change in the source ([examples/](../examples/) keeps it to ten lines).

Not run here: none of the tested phones has a compiler [m]. The script is the
method in ten lines; a build on the phone is [u], on an NDK host it is [s].

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `Bad system call`, process killed | the program (or its static libc) issued a syscall Android's filter traps | build against bionic, or answer the call at the [boundary](tracer.md) |
| `cannot locate symbol "..."` at start | built against a newer API level than the device provides | lower the NDK API level, or ship the symbol |
| the rebuilt program still writes `/usr/share` | the patch covered some paths and not all | `strings` the binary for absolute paths; patch the rest |

## By domain

A rebuilt bionic binary in app data still obeys the `execve` rule
([reference/domains.md](../reference/domains.md)); in shell and root it runs
directly. Building for the tree's glibc works wherever that tree runs.

## Evidence

The `SIGSYS` death of a static glibc client, and an 8 KB client built with `clang`
against bionic, are [s]; the dropbear result is measured on a reference device [m].

