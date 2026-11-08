# Patch the package

Isolation **1**. Act once, before anything runs: edit the files a package contains
— the ELF's `PT_INTERP`, a script's shebang, a library's `rpath` — and repack. It is
the cheapest way to make a *prebuilt* program find the tree, and the most brittle
when the tree moves.

## What it buys

- **No run-time layer at all**: the program starts through the tree's loader and
  then talks to Android's kernel directly.
- **It scales with the package manager**: the edit happens per `.deb`, before
  the first maintainer script runs, so `apt` installs unmodified.
- **It is idempotent**: a file already pointing at the tree is left alone.

## What it costs

- **The path is baked.** Move or copy the tree and every patched binary breaks.
  A relocatable tree uses a loader that derives its prefix from its own location
  ([loader](loader.md)).
- **It cannot reach inside a static binary** — no `PT_INTERP` to edit
  ([rebuild](rebuild.md) is the answer).
- **Each edit is a format contract**: the string must land where `p_vaddr` points,
  not merely at a new offset, because glibc names itself from memory
  (`_dl_rtld_libname.name = main_map->l_addr + p_vaddr`) [s].

## The three edits

- `PT_INTERP` — the one field that decides whether the program starts.
- **shebang** — `#!/bin/sh` resolves against the real root too; rewrite it, or ship a
  real-ELF interpreter that sets up the environment and `exec`s the real one.
- **rpath** — a bionic library can live in the tree and be found through an `rpath`
  baked at build time; that is how a host-material tree ships one shared library
  without a loader ([tree/bionic.md](../tree/bionic.md)).

## Example

[examples/elf-interp.sh](../examples/elf-interp.sh) rewrites `PT_INTERP` in every
dynamic ELF, idempotently, and leaves a static binary or a shared library alone:

```sh
elf() { [ "$(head -c 4 "$1" | od -An -tx1 | tr -d " \n")" = "7f454c46" ]; }
cur=$(patchelf --print-interpreter "$f" 2>/dev/null) || continue   # no PT_INTERP
[ "$cur" = "$loader" ] && continue
patchelf --set-interpreter "$loader" "$f"
```

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `No such file or directory` running a file that exists | the kernel resolved `PT_INTERP` against the real root and got `ENOENT` | `readelf -l`: does the interpreter exist at that path? |
| every binary breaks after the tree is copied | the patched absolute path no longer exists | re-patch, or switch to a prefix-aware loader |
| `Text file busy` while patching | the file is being executed | patch before install, or write a temp and rename |
| `bad interpreter: No such file or directory` on a script | shebang against the real root, or CRLF | `od -c` the first line |

## By domain

The edit is domain-independent; whether the result may run is not. App data is
`execve`-refused at `targetSdk` ≥ 29 ([reference/domains.md](../reference/domains.md)).

## Evidence

The `p_offset`/`p_vaddr` rule follows from glibc's own `elf/rtld.c` [s]; the
per-file translation was used to build the measured prefixes [m].

## A bundle, not a tree

The smallest form of this surface: a program plus its closure — a loader, a
`ld.so.cache`, the libraries — with no `dpkg`, no `apt`, no FHS promise. The reference
bundle is about 7 MB: one static `busybox` (271 applet symlinks) plus a glibc
`fastfetch` and the loader with three libraries [m]. Fastest route to one program
on a phone, and not a system: no dependency resolution, no package database, and
a program that expects `/usr/share` still fails.
