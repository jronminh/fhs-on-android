# Ingredients: a Debian arm64 userland on a Linux host

**Goal.** Obtain a Debian `arm64` userland without emulating anything, to take
the three files the [glibc chroot recipe](chroot-glibc.md) needs — or to keep the
whole tree for a later step. No phone is involved.

**Tested on.** Debian (WSL 2), `debootstrap` 1.0.141, 2026-11-08 [m]. This is a
host-side measurement, not a phone one.

**Prerequisites.**

- a Linux host with `debootstrap` (`sudo apt-get install debootstrap`);
- network access to a Debian mirror;
- about 250 MB free;
- no `qemu-user-static`: `--foreign` only fetches and extracts.

**Time and size.** **64 seconds** and **225 MB** for `--variant=minbase trixie`
on the host above.

**Steps.**

1. Fetch and extract, without running anything from the tree:

   ```sh
   sudo debootstrap --foreign --arch=arm64 --variant=minbase \
     trixie /tmp/trixie-arm64 http://deb.debian.org/debian
   ```

2. Check the three files the chroot recipe takes:

   ```sh
   ls -l /tmp/trixie-arm64/usr/bin/dash \
         /tmp/trixie-arm64/usr/lib/aarch64-linux-gnu/libc.so.6 \
         /tmp/trixie-arm64/usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1
   ```

3. Either copy those three, or keep the tree for the phone:

   ```sh
   tar -C /tmp -czf trixie-arm64.tar.gz trixie-arm64   # to push later
   ```

**Expected.**

```
-rwxr-xr-x 1 root root  199256 Feb  4  2025 usr/bin/dash
-rwxr-xr-x 1 root root 1716616 Jun 29 21:37 usr/lib/aarch64-linux-gnu/libc.so.6
-rwxr-xr-x 1 root root  201344 Jun 29 21:37 usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1
225M  /tmp/trixie-arm64
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `E: Release file ... is not valid yet` | the host clock is behind the mirror's | set the clock, then retry |
| `rm: cannot remove ...: Permission denied` on a retry | the previous run left root-owned files | `sudo rm -rf` the directory before retrying |
| extraction stops partway | disk full, or the mirror closed the connection | `df -h`, then retry with `sudo rm -rf` first |

**Undo.**

```sh
sudo rm -rf /tmp/trixie-arm64 /tmp/trixie-arm64.tar.gz
```

**Cost.** `--foreign` extracts the packages and stops: there is no configured
package database and no maintainer script has run, so this is **ingredients**, not
a working tree. The second stage is the sketch in [the index](README.md#sketches-not-recipes-yet).
