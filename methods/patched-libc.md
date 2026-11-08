# Keep the distribution's libc, patch ten files

Isolation **1**. Take the distribution's `libc6` and `libc-bin` and replace the
files an Android patch changes — **ten files**; everything else stays the
distribution's. The smallest libc change that still gives a tree its own paths,
and it shipped: the list is in deb-native `core/install/dn-fix-glibc.sh`
(2026-10-05) [s], retired on 2026-10-12 for stock `libc6`.

## What it buys

- **A complete glibc, not a fork.** Ten files of one package pair; the rest is
  the distribution's build, with its ABI [s].
- **A per-release re-check, not a rebuild.** A point release costs a check of ten
  files [u].
- **The clearest evidence about the kernel.** The ten differ over paths, passwd
  and group lookup, SysV IPC's absence and the loader's `LD_PRELOAD` — userland
  convention, not the ABI [s]; a distribution's `apt`, `dpkg` and `gcc` run on it
  [u]. "An arm64 Linux kernel with a different userland", as a measurement.

## What it costs

- **Forward-porting per release.** The patch follows glibc's source.
- **The set is derived, not obvious.** A binary comparison answers 283 files,
  nearly all build configuration; DWARF line tables give the set [u].
- **A guard is not optional.** `apt` puts the distribution's files back.
- **The tracer does not go away**: static, bionic and raw `syscall()` never reach the loader ([tracer](tracer.md)).

## The set

Paths are relative to the tree [s]; [examples/libc-swap.list](../examples/libc-swap.list) has them one per line.

```
usr/lib/aarch64-linux-gnu/:  ld-linux-aarch64.so.1 libc.so.6 libnsl.so.1
                             libnss_compat.so.2 libnss_hesiod.so.2
                             libresolv.so.2 librt.so.1
usr/sbin/ldconfig   usr/bin/iconv   usr/bin/localedef
```

Everything else stays the distribution's; `libc.so.6` defines `_nss_files_*` and
`_nss_dns_*` itself, and the `libnss_*` modules are ABI stubs [u].

## The guard, and the order

- **Stash and restore.** The patched copies live at
  `usr/lib/deb-native/glibc-swap/` in the tree; a restore compares each path
  against the stash and rewrites only what differs, into a temp file and a `mv`,
  from `apt`'s post-invoke hook — a `libc6` reinstall otherwise leaves stock
  glibc, "which is killed by Android at startup" [s]. The stash is the authority.
- **The loader first.** A maintainer script is a glibc ELF whose `PT_INTERP` is
  the tree's loader, so the loader and `libc.so.6` are seeded before the first
  package [s].
- **The cache is the tree's**: its `ldconfig` bakes a sysconfdir inside the tree,
  which is why the distribution's `ldconfig` cannot replace it [s].

## Example

[examples/libc-swap.sh](../examples/libc-swap.sh) is the guard in one file: it
seeds the stash, then restores only the paths whose content differs.

```sh
cp -a "$PATCHED/." "$STASH/"
cmp -s "$STASH/$rel" "$TREE/$rel" && continue
cp -f "$STASH/$rel" "$TREE/$rel.tmp" && mv -f "$TREE/$rel.tmp" "$TREE/$rel"
```

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| every program aborts at start, naming a preload or a `GLIBC_` version | stock glibc is live, or a host `LD_PRELOAD` reached a loader without the patch | `cmp` the tree's `libc.so.6` with the stash; unset `LD_PRELOAD` |
| it worked, then an upgrade broke it | the post-invoke hook is not wired, or the stash is gone | run the restore by hand; it prints how many files it restored |
| a program reads the phone's `/etc` | a static binary, or a raw `syscall()` | the tracer's case, not this one |
| `ldd` shows the host's libraries | the program is static, or `PT_INTERP` names another loader | `readelf -l` the program |
| `getent` finds nothing | the lookup went to a stub module, or the passwd path is not where the patch points | `getent passwd 2000` with the tree's libc |

## By domain

The swap needs a writable tree and `execve` of it: fine in **shell** and
**root**, refused in **app** data at `targetSdk` 29 and above. Gate A is
unchanged: a trapped call is still a signal, whichever libc is loaded.

## Evidence

- **[s]** the ten files, the stash, the post-invoke restore and the seeding
  order: `core/install/dn-fix-glibc.sh` (commit `f0331fe`, 2026-10-05) and
  `bootstrap/dn-install-glibc.sh`. The other packaging —
  `scripts/glibc/dn-package-glibc.sh` and `dn-package-libc-bin.sh` — repackages
  Debian's `.deb`s with a `+dn1` version; `libc-bin` needed its own because its
  programs bake a sysconfdir, while `libc6-dev` needs only the same version.
- **[u]** the run: retired at `2a69cba` (2026-10-12), which deleted the patch,
  both packaging scripts and the workflow. This guide has not re-run it.
- **[m]** that a distribution's userland runs on these kernels at all:
  `debootstrap --foreign` and a full Debian tree with `apt`
  ([tree/glibc.md](../tree/glibc.md),
  [the chroot recipes](../recipes/debian-chroot-full.md)).
