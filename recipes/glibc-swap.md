# Keep the distribution's glibc: the ten-file swap

**Goal.** A tree whose glibc is the distribution's own, with the ten files an
Android patch changed replaced by the project's build — and a restore step so a
package manager cannot put the stock ones back. **Isolation 1**: no layer at run
time, one edit per file.

**Recorded.** The mechanism is read in deb-native's history, not re-run for this
repository: `core/install/dn-fix-glibc.sh` (commit `f0331fe`, 2026-10-05) lists
the ten files and carries the restore; the approach was retired on 2026-10-12
(`2a69cba`, "the tree takes stock libc6 from the mirror"). The method is
[patched libc](../methods/patched-libc.md).

**Prerequisites.**

- Debian arm64 `libc6` and `libc-bin`, the same version the patched build was
  made against;
- the patched build's ten files, at their tree-relative paths;
- a tree with Debian's layout (`usr/lib/aarch64-linux-gnu`);
- about 300 MB free on the phone while both sets are present.

**Time and size.** Minutes once the patched build exists; the build itself is
hours, on a Linux host, and is not this recipe.

**Steps.**

1. Install the distribution's packages into the tree, unchanged:

   ```sh
   dpkg-deb -x libc6_*.deb "$TREE"
   dpkg-deb -x libc-bin_*.deb "$TREE"
   ```

2. Put the patched ten in a directory of their own, mirroring the tree's layout:

   ```sh
   PATCHED=/tmp/patched-libc      # usr/lib/aarch64-linux-gnu/..., usr/sbin/...
   ls "$PATCHED"/usr/lib/aarch64-linux-gnu
   ```

3. Stash them and restore the live copies — the loader and `libc.so.6` first,
   because a maintainer script is itself a glibc ELF whose `PT_INTERP` is the
   tree's loader:

   ```sh
   examples/libc-swap.sh "$TREE" "$PATCHED"
   ```

4. Copy the restore script into the tree and run it from `apt`'s post-invoke, so
   a `libc6`/`libc-bin` reinstall cannot silently leave stock glibc:

   ```sh
   cp <deb-native>/core/install/dn-fix-glibc.sh "$TREE/usr/lib/deb-native/"
   printf 'DPkg::Post-Invoke { "%s/usr/lib/deb-native/dn-fix-glibc.sh %s"; };\n' \
       "$TREE" "$TREE" > "$TREE/etc/apt/apt.conf.d/99-glibc-swap"
   ```

5. Check from inside the tree: the loader, a lookup, and a program.

   ```sh
   "$TREE/usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1" --version | head -n 1
   ldd "$TREE/usr/bin/getent"
   getent passwd 2000
   ```

**Expected.** `stashed: 10 files`, then `restored: 10 files` on a stock tree and
`restored: 0 files` on the second run — the restore is idempotent. The loader
reports the distribution's glibc version, `ldd` names the tree's paths, and
`getent passwd 2000` answers. In the project's build the patched `ldconfig` was
a 4.76 MB binary of its own [u].

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| every program aborts at start, naming a preload or a `GLIBC_` version | stock glibc is live, or an inherited `LD_PRELOAD` reached a loader without the patch | `cmp` the tree's `libc.so.6` with the stash; unset `LD_PRELOAD` |
| `restored: 0` but programs fail | the stash was seeded from the wrong build | `cmp` one file against the patched copy |
| it worked, then an upgrade broke it | step 4 is missing | run step 3 again, then add the hook |
| `ldd` shows the host's libraries | the program is static, or `PT_INTERP` names another loader | `readelf -l` the program |
| `getent` answers nothing | the passwd path is not where the patch points | `getent passwd 2000` with the tree's libc |

**Undo.**

```sh
rm -rf "$TREE"          # or: re-extract the two .debs over it
rm -rf /tmp/patched-libc
```

**Cost.** Ten files to keep in step per release, a stash inside the tree, and a
tracer for what never reaches the loader ([patched libc](../methods/patched-libc.md),
"What it costs"). What it buys is a full glibc with the tree's own paths, and
the smallest measured difference between a distribution's userland and this
platform.
