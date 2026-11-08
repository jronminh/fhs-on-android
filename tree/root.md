# The tree on a rooted phone

Root is not a method on this page; it is a change of contract. What it changes is
narrow and worth stating plainly: the kernel starts answering the questions the
tree was faking, and one door opens that is closed everywhere else.

Measured on a Magisk-rooted phone (Android 15, kernel 5.4.242), 2026-11-08 [m]:

| check, as root | result |
| --- | --- |
| `su -c id` | `uid=0(root)`, `context=u:r:magisk:s0` |
| `CapEff` | `0000003fffffffff` (the shell domain has `0`) |
| `chroot / /system/bin/true` | **ok** - level 4 is reachable |
| `unshare -Ur true` | `unshare: Invalid argument` - user namespaces stay refused, even as root |
| `[ -w /dev/kmsg ]` | yes - a log sink that outlives a userland |
| boot partition | `67108864` bytes (64 MB total), the size that decides what may live there |
| SELinux | `Enforcing` |

## Level 4, end to end

A 1.7 MB tree made from one static busybox (359 applets), `proc`/`sys`/`dev` bound in,
entered with `chroot` as root, 2026-11-08 [m]:

```
tree: 359 applets, 1721 KB
id       : uid=0(root) gid=0(root)
kernel   : 5.4.242-30976065-abG990EXXUDGYD4
rootfs   : bin dev etc proc sys tmp
proc     : Linux version 5.4.242-30976065-abG990EXXUDGYD4
static   : runs
isolation: /system -> ls: /system: No such file or directory
```

The last two lines state the trade: a static binary needs nothing from the phone
and runs, while the phone's `/system` is out of reach. That is what level 4
provides and what it removes.

One detail to record: applet symlinks must be **relative**. Absolute links name
the tree's path from outside, which does not exist inside, and the chroot fails
with `exec /bin/sh: No such file or directory`.

### With a glibc tree

The same shape, and no more expensive to enter: three files (`dash`, libc, loader)
make a 2.1 MB tree that reports `Debian GLIBC 2.41` from inside the chroot [m].
The loader must be executable — 0644 gives `Permission denied`, not `ENOENT`,
which is what an `adb push` produces.

## What root changes for the tree

- **Identity stops being constructed.** `chown`, setuid bits and `id` are the kernel's
  answers, so the [identity](../methods/identity.md) page's whole table collapses to
  one row. The tree no longer constructs identity, and no layer has to answer for it.
- **Level 4 becomes available.** `chroot` works, so the path problem can be solved by
  the kernel instead of by a [shim](../methods/loader.md) or a [tracer](../methods/tracer.md).
  What it does *not* give is user namespaces: `unshare` is refused even as root on
  this device, so the rootless form of level 4 is still a design.
- **A place to live.** `/data/adb` survives a reboot, and the boot ramdisk
  survives a factory reset ([durability](durability.md)).
- **An init that can start the tree.** A boot hook runs in the `magisk` context with
  no app and no `su` binary; that is why the restore script must not depend on
  either ([durability](durability.md#the-boot-image-frame)).
- **The small conveniences that decide a design**: ports below 1024, `tun`, raw
  sockets, a writable kernel log.

## What it costs

- the unlock is one-way in practice: attestation trips, and some vendor releases
  later remove unlocking, which turns OTA blocking into a boot-critical feature;
- the boot image is a fragile artifact: re-running a rooting tool's install
  regenerates it and drops the overlay;
- a bug at boot is unrecoverable without a PC, which is why every boot script
  needs idempotency, a restart budget and an independent way in;
- you now own the phone's security posture: SELinux stays enforcing, but the tree
  is part of what the phone trusts.

## What it does not change

A glibc userland still needs its loader found and its library cache resolved
([tree/glibc.md](glibc.md)); a static binary still sees the phone's paths; a shim
or a tracer is still the only run-time answer for code the kernel will not
execute as asked. Root removes the *identity* problem and opens level 4; it does
not remove the path problem.

## The rule for a tree that lives on a rooted phone

**The tree is a device, not a session.** Every feature declares its durability
level (reboot or reset), its test, and what it does when the framework is not up
yet. A tree that cannot say which level it is at is guessing.
