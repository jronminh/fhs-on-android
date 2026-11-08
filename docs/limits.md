# 8. Limits: the failure catalogue

Symptoms, in the order people meet them. Each row names the cause, which gate or
class it belongs to ([the problem](the-problem.md)), and the cheapest fix that is
honest. Rows marked **unfixable** are not a matter of a better implementation.

## First: which of the three is it?

Before reading the table, one test decides most cases:

```sh
ldd ./program                # or: readelf -l ./program | grep interpreter
```

- **fails with "not a dynamic executable"** — a static binary, so the loader is
  not the problem; the failure is paths or the kernel;
- **fails with "not found" for the interpreter** — the loader is the problem,
  class A;
- **shows the tree's libraries** — the entry point is fine, so the failure is a
  path the program computed itself, an identity answer, or a kernel refusal.

Then bisect the layer: turn the shim off, then the userland exec
([the build recipe](foreign-tree.md#when-bar-2-fails)). If the behaviour changes, the layer
is at fault; if it does not, the platform is.

## Loader and ELF

| symptom | cause | class | fix |
| --- | --- | --- | --- |
| `No such file or directory` running a file that obviously exists | the kernel resolved `PT_INTERP` against the **real** root and got `ENOENT` | A | make the interpreter resolvable: rewrite `PT_INTERP`, or run the tree's loader explicitly, or let the runtime's exec decide |
| `error while loading shared libraries: libfoo.so.1: cannot open shared object file` | `DT_NEEDED` resolved through the real root's cache, not the tree's | A | the tree's own `ld.so.cache` (`ldconfig` inside the tree) is the correct fix; `LD_LIBRARY_PATH` is the quick one and is scrubbed at trust boundaries |
| `cannot execute: required file not found` (glibc's own message) | the loader ran and could not find the program or a library | A | as above; check the program's own `ldd` under the loader |
| `Exec format error` on a valid `arm64` binary | wrong architecture (an `amd64` tarball, or an `armhf` one) | — | check `readelf -h`; `uname -m` says `aarch64` |
| `Text file busy` while patching a binary | the file is being executed, or was executed from this inode | — | write to a temp name and `rename(2)` |
| works at 4 KB pages, fails on a 16 KB-page device | segment alignment and native-lib packaging assume 4 KB | — | build/link for 16 KB; this is a build-system property, not a runtime one [s]/[u] per device |

## Paths

| symptom | cause | class | fix |
| --- | --- | --- | --- |
| a program reads the **phone's** `/etc` or `/usr/share` | nothing translated its paths (static binary, raw syscall, or app that bypasses libc) | A | it must run under the tracer, or be rebuilt |
| `#!/bin/sh` script: `bad interpreter: No such file or directory` | shebang resolved against the real root | A+B | rewrite the shebang, or use a generic real-ELF interpreter that redirects |
| the same script fails with `not found` and the file looks perfect | CRLF line endings in the shebang | — | `dos2unix`; a `\r` makes the interpreter name unresolvable |
| `find`/`du` disagree with `df` | `/proc/self/mounts` and `statvfs` report the **phone's** filesystem, not the tree | — | expected; a tree is a directory, not a mount |
| `ldconfig` writes to `/etc/ld.so.cache` at the real root | `ldconfig` is not prefix-aware; it uses absolute paths | A | run it with the tree's paths as its arguments, or ship a loader that derives its prefix |
| `setlocale: LC_ALL: cannot change locale` | no locales generated in the tree | — | `apt install locales && locale-gen C.UTF-8` (and keep `LANG=C.UTF-8`) |
| random `invalid ELF header` on Termux | a foreign `glibc` directory sits first on `PATH` and shadows the bionic coreutils | — | `export PATH=$PREFIX/bin:$PATH` explicitly; it is a host problem, not a tree problem |

## Identity

| symptom | cause | class | fix |
| --- | --- | --- | --- |
| `chown: Operation not permitted` | no `CAP_CHOWN`; the kernel answers `EPERM` | B | identity layer answers "success"; the file's real owner does not change |
| `sudo: must be setuid root` | an unprivileged `tar`/`adb push` dropped the setuid bit | — | record setuid files at build time and restore them at boot |
| `setuid()` returns `EPERM` from a "root" shell | the process is not privileged; `setuid` cannot be faked at the symbol layer for a real syscall | B | the identity layer answers at the syscall boundary; real privilege is out of reach |
| `whoami` says `root` but `id` says `u0_aNNN` | one of the two reads through a different layer | A | a documentation bug: make both answers come from the same owner |
| `passwd` cannot change a password | `shadow` writes need `chown`/`chmod` semantics the layer only pretends to have | B | fix file ownership in the tree at build time; accept that `passwd` is cosmetic without privilege |
| **unfixable**: a real extra uid | the kernel has one uid per process; there is no second | B | design around it: virtual principals, or one tree per real uid |

## Kernel refusals

| symptom | cause | gate | fix |
| --- | --- | --- | --- |
| `Bad system call` (signal 31) or the shell reporting a killed process | the app's seccomp filter trapped the call; `TRAP` outranks `ERRNO`, so no errno can be returned | A | a handler installed before the first instruction, or a supervisor; a fast path with no supervisor cannot fix it |
| `io_uring_setup: Function not implemented` (after a trap) | a newer syscall the sandbox traps, and glibc probes then falls back — sometimes it does not | A | trap the signal and return `ENOSYS` honestly; most software then falls back |
| `mount: Permission denied` | no `CAP_SYS_ADMIN` | B | **unfixable** without root; a tree is not a mount |
| `ping: Operation not permitted`, `socket(AF_PACKET)` fails | no `CAP_NET_RAW` | B | **unfixable**; use a userspace ping (TCP) and mark it as such |
| binding port 80/443 fails | ports below 1024 need `CAP_NET_BIND_SERVICE` | B | bind a high port and forward, or serve on the tether address |
| `/dev/net/tun` missing, VPN tools fail | no tun device for the app domain | B/C | **unfixable** without root; wireguard-style tools need the host |
| `systemctl` says "System has not been booted with systemd" | there is no PID 1 to talk to, and no cgroup delegation | — | a userspace supervisor (`runit`), or run services from the host |
| `dpkg` blocks on `invoke-rc.d`/`policy-rc.d` | maintainer scripts try to start services during install | — | ship `/usr/sbin/policy-rc.d` returning 101 in the tree |

## Host and packaging

| symptom | cause | fix |
| --- | --- | --- |
| `Permission denied` on a `+x` file in app data | `targetSdk ≥ 29`: `execve` of app data is refused (SELinux) | userland exec (M7), or `targetSdk 28` as a stopgap |
| the tree dies when the cable is unplugged, or after a reboot | the `adbd` domain does not outlive its parent; nothing restarts it | a re-attach loop on the PC side, or an app-domain host |
| `df` reports the phone's free space, and `apt` hits a quota | the tree lives in app data with a quota; `statvfs` answers for the phone | keep the tree small; `apt clean`; move `var/cache/apt` out |
| a 51 MB tree becomes a 100 MB asset, or shrinks to half after extraction | the asset is a compressed copy of the tree; sparse files, hardlink tricks and `var/cache/apt` do not survive the round trip | build the asset from a cleaned tree (`apt clean`, no cache, no `ld.so.cache`) and check the *unpacked* size on the device |
| installs work, then break after an `apt upgrade` | a hook path baked at build time went stale | re-derive hooks from the tree location at every post-change hook |
| **unfixable**: kernel modules, `iptables`, raw devices, DRM/KMS for an app | not granted to any non-root domain | use the device table (a broker process, or the GPU's own `pass` device) or root |

## A durable tree (poor host, root)

These are the failures of bar 4 — "it comes back" — and they are almost never
about paths ([a poor-host tree](poor-host-tree.md), [root](root.md)).

| symptom | cause | fix |
| --- | --- | --- |
| `echo: write error: Permission denied` for `/dev/kmsg`, and the script stops | rootless: the shell itself reports the redirect failure, not the syscall | guard every sink: `[ -w /dev/kmsg ] && ...`; the file log is the portable one |
| the tree is gone after a factory reset | its source lived in `/data` (anything there is reset) | the source goes in the boot image's `overlay.d`, and a boot script restores it |
| the tree comes back, but stale | the restore step compared a version it never wrote | write a version file at pack time and make the comparison total (missing = restore) |
| a setting changed before the reboot is back to its old value after it | the platform's write is delayed | wait ~30 s after a `pm`/`settings` change before rebooting; otherwise the test tested nothing |
| the boot script cannot find `su` | after a reset the rooting app and `su` are gone from `/data`; init runs the script directly | run from init in the root context; never depend on `su` existing |
| the overlay silently disappears | re-running the rooting tool's "direct install" regenerates the boot image | re-add the overlay in the same session, and verify it after every rooting update |
| `cmd`/`svc`/`content` fail while ADB and the tree still answer | the framework (`system_server`, ART) is down; those tools start a runtime per call | keep the rescue path on the native plane: shell, static binaries, ADB |
| the vendor refuses a device-owner app | attestation tripped by the unlock | the tree is the management surface; do not plan on an app for policy |
| a new boot image does not fit | the boot partition is small (about 34 MB free with a 29 MB kernel on the reference device) | the boot image carries scripts and one small tarball, not a distribution |

## How to report a failure

If you open an issue here or anywhere else, include: **which kind of tree**
(foreign or poor-host), device model, Android version, kernel (`uname -r`), host
(Termux/APK/adb/root), `Seccomp:` and `CapEff` from `/proc/self/status`, the exact
command, the exact error, and whether the same command works with the shim off.
Without the host and the kernel, the same error string means three different
things.
