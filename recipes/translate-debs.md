# Install Debian packages into a tree: translate each `.deb` first

**Goal.** A tree that `dpkg -i` a real Debian package without a `chroot`: every
glibc ELF in it names the tree's loader, every script names the tree's
interpreter, and `dpkg` sees a package it accepts. **Isolation 1.**

**Basis.** **Recorded** — the project's translation step before 0.9 dropped the
overlay (`dn-translate-deb.sh`, in deb-native's history). Not re-run for this
repository. The domain facts it needs were checked on both phones, 2026-11-08
[m]: `Seccomp: 0`, `/data/local/tmp` writable, **no `patchelf`**, `readelf` only
on Android 12 (absent on the 701SH).

**Prerequisites.**

- a tree with a loader at `usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1`;
- an ELF editor that writes `PT_INTERP`: `patchelf` on the host, or the tree's
  own editor (the project's `dn-elf`) — not on the phone [m];
- `dpkg-deb` and `tar` (host, or inside the tree).

**Time and size.** A second or two per package; the package is rewritten in
place, so keep the original.

**Steps.**

1. Unpack the control half, and the data without hard links — Android refuses
   `link(2)`, and `perl-base` ships one:

   ```sh
   dpkg-deb -e "$DEB" "$W/DEBIAN"
   dpkg-deb --fsys-tarfile "$DEB" | tar -xpf - -C "$W" --exclude-from="$W/hardlinks.exclude"
   ```

2. Make the architecture the manager expects:

   ```sh
   sed -i 's/^Architecture: all$/Architecture: arm64/' "$W/DEBIAN/control"
   ```

3. Point every dynamic ELF at the tree's loader, and fail if one cannot be
   written — a binary left pointing at `/lib/ld-linux-aarch64.so.1` installs
   fine and dies at `exec` with `ENOENT`:

   ```sh
   interp=$("$ELF" get-interp "$f" 2>/dev/null) || continue   # static: expected
   case $interp in */ld-linux-aarch64.so.1)
       [ "$interp" = "$LD" ] || "$ELF" set-interp "$f" "$LD" ;;
   esac
   ```

4. Rewrite the shebang of every maintainer script and program script to the
   tree's interpreter, keeping any flag (`#!/bin/sh -e` keeps its ` -e`); for
   `perl`, add a `BEGIN` line that puts the tree's module directories first,
   because a shebang line is too short to carry them.

5. If a maintainer script calls `update-alternatives`, wrap it: the call runs
   the tree's binary, then rewrites the links it wrote to relative ones —
   `../../` is right for every alternatives group.

6. Repack, uncompressed, and replace the input:

   ```sh
   dpkg-deb -Znone -b "$W" "$W/out.deb" && mv -f "$W/out.deb" "$DEB"
   ```

**Expected.** `dpkg -i` in the tree succeeds; the package's binaries run; a
program's `PT_INTERP` names the tree's loader, and its scripts' first line names
the tree's shell. The step is silent on success and exits 1 at the first
failure, so `apt` never installs a half-translated package.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `dpkg: error: ... architecture 'all' does not match` | step 2 skipped | the control file |
| a binary installs and dies with `No such file or directory` | `PT_INTERP` still names Debian's loader | `readelf -l` it (on Android 10, use the tree's tools or the host) |
| `dpkg` stops in `preinst` with `not found` | a maintainer script's shebang was not rewritten | `head -1` the script in the package |
| an alternatives link is absolute and breaks outside | step 5 skipped | `readlink` the link in the tree |
| the package replaced and now the original is gone | the script rewrites the input | keep a copy before translating |

**Undo.** Re-download the package (`apt-get download pkg=version`); the
translation has no other state.

**Cost.** The loader path is baked into every translated binary, so a tree that
moves needs re-translation — the reason
[a loader that derives its prefix](../methods/loader.md) is the better trade
when the tree is meant to move.
