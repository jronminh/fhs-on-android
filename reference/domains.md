# The three domains

A **domain** is the security context a process runs in; a **host** is what puts you
in one. There are three domains, and the difference between them is what the
platform permits — not what the UI looks like. Every [method](../methods/README.md)
pays its price differently in each.

| domain | uid | Gate A | `execve` of app data | what it decides | hosts |
| --- | --- | --- | --- | --- | --- |
| **app** | `u0_aNNN` | yes | only at `targetSdk` ≤ 28 | the filter kills; the app's lifetime ends the tree | Termux, a custom APK |
| **shell** | `2000` | **no** | yes | the easiest domain; nothing outlives `adbd` | `adb shell` |
| **root** | 0 | no | yes | capabilities, `chroot`, mounts, the boot image | Magisk or similar |

## The app domain

Two hosts, one domain: `u0_aNNN` under the app's own seccomp filter, with Gate A
present and `execve` of app data refused once `targetSdk` reaches 29. The host
changes the UI and the lifetime, not the domain.

- **Termux** gives an equipped environment and a way to build the tree on the
  phone; it ships at `targetSdk 28` [s], which is what makes running binaries out
  of its data directory legal — a clock, not a design.
- **A custom APK** gives a terminal UI and a foreground service; above `targetSdk`
  28 it needs [a userland exec](../methods/exec.md) and never asks the kernel to
  `execve` app data.

## The shell domain

`2000(shell)`, no app, no filter, a prefix under `/data/local/tmp`, driven over
ADB. `Seccomp: 0` [m] means no Gate A at all: the easiest domain, and the best
for measuring. Its rule is lifetime — a process started here does not outlive the
`adbd` that started it [m], so a long-running service needs a re-attach loop from the
PC side. The *files* do survive.

## The root domain

Measured on a Magisk phone (Android 15, 2026-11-08) [m]: `su -c id` gives
`uid=0`, `context=u:r:magisk:s0`; `chroot / /system/bin/true` succeeds;
`unshare -Ur` still answers `Invalid argument`; `/dev/kmsg` is writable. What that
means for the tree, and what it costs: [tree/root.md](../tree/root.md).

The only domain with capabilities: real `chown`, real setuid, `mount`, `chroot`, `tun`,
raw sockets, ports below 1024, a writable kernel log — and the boot image, the
only place a factory reset does not reach ([tree/durability.md](../tree/durability.md)).
The price is the unlock: attestation, some vendor features, and an OTA obligation
on devices whose next release removes unlocking.

## The four hosts side by side

| | Termux | custom APK | `adb shell` | root |
| --- | --- | --- | --- | --- |
| domain | app | app | shell | root |
| Gate A | yes | yes | **no** | no |
| `execve` of the tree | only at `targetSdk` 28 or below | same | yes | yes |
| tree location | app data | app data | `/data/local/tmp` | anywhere |
| survives a reboot | if the app starts it | if a service starts it | yes (files), not as a process | yes |
| survives a factory reset | no | no | no | **yes, from the boot image** |
| survives `adbd` restart | yes | yes | **no** | yes |
| usable by a normal user | yes | yes | no | no |
| best for | building, experimenting | the product | headless, measuring | lab devices |

## What a host must supply

The tree cannot know about Android, so the host answers four questions: the
session (a pty, `HOME`, `PATH`, `TMPDIR`, who am I); boot inputs (where the tree
is, which binds, which host variables to keep); the Android services the tree
cannot reach (DNS — the resolver is `netd` — clipboard, notifications); and the
device nodes the domain may open. Keeping those in the host, and out of the path
rule, is what makes one runtime serve several hosts.

## How to tell which domain you are in

```sh
id -u                      # 2000 = adb, 10xxx = app, 0 = root
grep Seccomp /proc/self/status
cat /proc/self/attr/current
getprop ro.build.version.sdk
```

[examples/probe.sh](../examples/probe.sh) collects these plus the capabilities, the page
size and a set of "does this actually work" tests in one read-only run.
