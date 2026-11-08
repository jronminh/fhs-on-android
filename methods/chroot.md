# The isolated end: namespaces, chroot, a VM

Isolation **4-5**. Level 4 is the highest that has been entered end to end here:
a 1.7 MB busybox tree, `proc`/`sys`/`dev` bound in, `chroot` as root, 2026-11-08
[m]. Level 5 (a virtual machine) is designed from the platform's rules, not from a
run [u].

## What it buys

- **A real root for the tree**: `chroot` to it, bind `/proc`, `/sys`, `/dev`, and the
  path problem disappears - no shim, no tracer, native speed.
- **The most complete form of a tree as a root**: inside it, `/` *is* the tree, for every
  program, without teaching any of them.
- **With namespaces**, in theory, the same view without a rooted phone - which the
  probed kernels refuse ([reference/domains.md](../reference/domains.md)).

## What it costs

- **Privilege**: without root the kernel refuses. In the shell domain all three
  tested phones answered `chroot: refused (125)` [m].
- **Reach**: a tree with its own `/dev` and `/proc` stops seeing the phone's. In the
  measured run `/system` answered `No such file or directory` - that is the cost,
  not a bug.
- **Recovery**: a bind that hangs at boot takes the only network path with it - the
  frame in [tree/durability.md](../tree/durability.md) exists for this class.
- **A VM** (level 5) buys everything and costs the phone: it is a host for a guest,
  not a platform on Android.

## Example

[examples/root-chroot.sh](../examples/root-chroot.sh) is the run in one file: copy a
static busybox, make the applets, bind the kernel filesystems, enter.

```sh
(cd "$TREE/bin" && "$TREE/bin/busybox" --list | while read -r a; do ln -sfn busybox "$a"; done)
mount -t proc proc "$TREE/proc"
mount -t sysfs sysfs "$TREE/sys"
mount -o bind /dev "$TREE/dev"
chroot "$TREE" /bin/sh -c 'PATH=/bin; id; uname -r; ls /'
```

Measured output, 2026-11-08, Magisk phone (Android 15, kernel 5.4.242) [m]:

```
tree: 359 applets, 1721 KB
id       : uid=0(root) gid=0(root)
rootfs   : bin dev etc proc sys tmp
static   : runs
isolation: /system -> ls: /system: No such file or directory
```

The last two lines are the trade in one screen: a static binary runs and needs
nothing from the phone, while the phone's own `/system` is out of reach.

### With a glibc userland

[examples/glibc-chroot.sh](../examples/glibc-chroot.sh) takes three files from a
glibc userland — `dash`, `libc.so.6`, `ld-linux-aarch64.so.1` — and builds a
**2.1 MB** tree. Measured on the rooted phone, 2026-11-08 [m]:

```
tree: 2101 KB
ld.so (Debian GLIBC 2.41-12+deb13u4) stable release version 2.41.
proc  : Linux version 5.4.242-30976065-abG990EXXUDGYD4
math  : 42
system: absent
```

So level 4 runs a **dynamic glibc program** with no shim and no tracer: a `dash`
linked against the tree's own libc, inside a root that is the tree. The `dash`
that ran also proves the loader found `libc.so.6` through the tree's own path.

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `mount: Permission denied` | no `CAP_SYS_ADMIN` | root, or a method below level 4 |
| `unshare: Operation not permitted` / `EINVAL` | the kernel forbids user namespaces for this caller, even as root | [examples/isolate-check.sh](../examples/isolate-check.sh); do not design around it until it succeeds |
| `chroot: exec /bin/sh: No such file or directory` although `/bin/sh` exists | applet symlinks are absolute and name the tree's path from outside | make them relative: `ln -sfn busybox sh` |
| programs work but see the phone's `/proc` | `/proc` was not bound | bind it and check `/proc/self/mounts` |
| the device boots to no network | a boot-time bind or namespace hang | the frame's idempotency and rescue path |

## The two loader states that come first

Before any of that works, `PT_INTERP` has to be satisfied, and the two failures are
distinguishable if you know them [m]:

- no loader at the path: `chroot: exec /bin/sh: No such file or directory`;
- the loader present but mode 0644: `chroot: exec /bin/sh: Permission denied`
  - and this is the trap, because `adb push` writes 0644 and `cp` keeps it.

## By domain

**Root only.** In app and shell the capabilities are absent: the same two checks
print `refused`, measured on Android 10, 12 and 15 [m].

## Evidence

The level-4 run, the relative-symlink failure and the namespace refusals are
measured on a rooted phone, 2026-11-08 [m]. Level 5 has no example and no run [u].
