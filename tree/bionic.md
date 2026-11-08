# Supply: the host's own material

**Poor host** is the term for a host that gives you `sh`, toybox and a loader —
and nothing else: no glibc, no compiler, no package manager, no `chroot`. A tree
built from that material is a layout plus your scripts, a few hundred kilobytes,
and it costs the least of the trees described here.

- **Buys** isolation level 0: nothing sits between the program and the kernel.
  Measured: one static busybox becomes a 359-applet tree of 1.7 MB that runs in a
  `chroot` as root ([root.md](root.md)) [m].
  Native speed, no loader problem, a floor as old as Android 6, and the only
  tree small enough to live in a boot image.
- **Costs** you write everything; there is no package manager; a foreign binary
  is still foreign and needs the [methods](../methods/README.md).
- **Native first**: add only what the ROM lacks. Every added binary is a thing to
  keep updated.

## What it is made of

| layer | source | why not the obvious alternative |
| --- | --- | --- |
| POSIX tools | **one busybox**, reached through a symlink farm | toybox applets and options change between AOSP versions, so behaviour depends on the phone; one busybox behaves the same everywhere |
| shell | Android's `mksh`; scripts in POSIX `sh` | it is already there and it is what `init` uses |
| framework actions | `getprop settings svc pm am dumpsys` | the platform's own interface; reimplementing it creates a second implementation to maintain |
| your commands | `bin/<name>` scripts, one verb set each ([methods/scripts.md](../methods/scripts.md)) | a command is a file, so it can be read, edited and called over ADB |
| state | `etc/` (intent) and `var/` (generated) | [the state rule](README.md#state) |
| supervisor | a shell loop with a respawn policy | there is no PID 1 to delegate to |

## Root is a mode, detected in one file

Nothing in the tree may assume root, and nothing may duplicate the check:

```sh
MODE=shell
[ "$(id -u 2>/dev/null)" = 0 ] && MODE=root
```

and the defaults follow from it: root serves ports below 1024, writes
`/dev/kmsg` and installs a boot hook; shell uses a high port, skips kmsg and is
started by hand. A feature that needs root says so, **refuses fast** with its own
exit status, and keeps working without it. That is the difference between a tree
that runs rootless and one that pretends to.

## What broke on a second device

Three failures from taking the tree to a rootless second device (Android 10,
kernel 4.4) [m], each a general lesson: an **assumption about the host** leaking
into the tree.

| symptom | cause | lesson |
| --- | --- | --- |
| every path wrong on the new device | the tree's root was hardcoded | derive it from `$0`; a tree that names its own path is not portable |
| a config file resolved to the wrong place | it was assumed to live in the boot ramdisk, which only a rooted device has | check for it, and fail loudly when it is missing |
| `echo > /dev/kmsg` printed a hard error | the sink was written unconditionally | guard it: `[ -w /dev/kmsg ]`, and always keep the file log |

## Cost of ownership

Every command is yours; there is no dependency resolution, so version pinning is
manual. The characteristic failure class is an assumption about the host leaking
into the tree — a hardcoded root, a file that exists only on a rooted device, a
sink that is not writable — and the fix is one file that answers "where am
I and what may I do", with no other file allowed to guess.
