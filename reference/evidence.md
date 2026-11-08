# Evidence

This guide exists because a lot of "Linux on Android" writing states platform
facts that are not true on the reader's phone. The defence is a device table and
a label on every claim.

## Devices

| device | Android | kernel | domains used | role |
| --- | --- | --- | --- | --- |
| Samsung Galaxy S10e (SM-G970W) | 12 | 4.14.190 | app, shell | the main measurement device for the glibc supply; all numbers in [measurement](./measure.md) |
| Sharp 701SH (SDM660, 3 GB) | 10 | 4.4.205 | shell | oldest kernel in the set; where "it works on 4.4 too" was checked, and the first **rootless** run of a bionic-native tree |
| Samsung Galaxy S21 FE (SM-G990E) | 15 | 5.4.242 | root | the host-material tree in production (24/7 uplink), the boot-image overlay, the durability claims |
| Samsung Galaxy S23 FE | 16 | — | app | builds an APK host, and the second-generation runtime target |

Kernel versions that are not filled in are not recorded, and are not guessed.

## Labels

| label | means | can you rely on it |
| --- | --- | --- |
| **[m]** | measured on one of the devices above, on a named date, with the command shown | for that device and that date; re-measure for yours |
| **[s]** | read in a specification or in source: AOSP, glibc, the kernel, an upstream README | as documentation; versions move |
| **[u]** | unverified: an assumption, a report from elsewhere, or a design that is not built | treat as a hypothesis |

Unlabelled prose is explanation — a model, a definition, a consequence — not a
platform fact. If you find an unlabelled sentence that reads as a fact, that is
a bug in this repository.

## What each page rests on

| claim | label | rests on |
| --- | --- | --- |
| a dynamic ELF fails before `main` when `PT_INTERP` is unresolvable, with `ENOENT` | [s] | ELF and `ld.so` semantics; reproducible in five minutes ([the build recipe](../tree/glibc.md#three-failures-in-five-minutes)) |
| an app-domain process can be killed by a seccomp `TRAP` (`SIGSYS`) where the `adb shell` domain has none | [m] | `Seccomp:` in `/proc/self/status`: `0` for uid 2000, non-zero in the app domain |
| no `CAP_SYS_ADMIN` in either domain, so `mount`/`chroot` fail | [m] | `CapEff` in `/proc/self/status`, plus the syscalls themselves |
| `execve` of app data is refused at `targetSdk ≥ 29` | [s] | the platform's SELinux policy (`untrusted_app`), and the failure mode when an app is lifted above 28 |
| a tree at native speed is reachable without root | [m] | the numbers in [measurement](./measure.md); 1.3–1.6× on the workloads listed |
| the same tree boots on a 4.4 kernel | [m] | Sharp 701SH, 2026-11 |
| proot's cost is "large on metadata, small on CPU" | [u] | widely reported; **this project has not measured it**. Measure before quoting |
| user namespaces are usually unavailable | [u] | reported per device; the only direct test is `unshare -Ur` on your phone ([examples/probe.sh](../examples/probe.sh)) |
| a 16 KB-page device breaks 4 KB assumptions | [s]/[u] | the platform documents 16 KB; the exact failure per build system is untested here |
| a high-`targetSdk` APK runtime with userland exec works | [u] | it is a design ([prior art](./prior-art.md)), not a shipped result |
| a host-material tree (busybox + the host's own tools) runs a device 24/7 | [m] | S21 FE, Android 15, root: web UI, services, ADB rescue, OTA blocked, tether re-applied each boot |
| the same tree runs with **no root at all** | [m] | Sharp 701SH, Android 10: pages served, most commands run, supervisor respawns; three assumptions broke, all about the host ([what broke](../tree/bionic.md#what-broke-on-a-second-device)) |
| a tree survives a factory reset when its source is in the boot image | [m] | S21 FE: simulated reset (state removed, reboot) → tree restored, version checked |
| rootless, writing `/dev/kmsg` is a hard shell error | [m] | 701SH, 2026-11-08 |
| the platform's package state has a delayed write (~30 s) | [m] | S21 FE: a reboot sooner than that tested nothing |
| a boot partition leaves roughly 34 MB free with a 29 MB kernel | [m] | S21 FE — the constraint that keeps the glibc-foreign tree out of the boot image |
| a device-owner app is refused once attestation trips | [m] | S21 FE, vendor policy; the tree became the management surface |
| `cmd`/`svc`/`content` survive or die with the framework; ADB does not | [m] | both devices; `svc` moved from ART to `cmd` between Android 10 and 15 |
| a bionic program's `PT_INTERP` is `/system/bin/linker64` | [m] | read on Android 12 and 15, 2026-11-08 |
| `readelf` is absent before Android 12 | [m] | sdk 29 has toybox without it; sdk 31 and 35 have it |
| the same static busybox works on Android 10, 12 and 15 | [m] | one 1.36.1.1 binary, 358 applets, identical on three phones, 2026-11-08 |
| the tools the farm provides also exist on `/system/bin`, `ip` as iproute2 | [m] | twenty names checked on all three; `ip utility, iproute2-ss171113` |
| a command with `status`/`check`/`adopt` behaves the same on three Android versions | [m] | adopt then check: 0; tampered intent: 1 with `diff sdk`; 2026-11-08 |
| a shell supervisor restarts its child without a PID 1 | [m] | 3 starts, 3 respawns, 0 left running on each of the three phones |
| a syscall site can be patched on disk with four bytes | [m] | `mov x8,#64` → `#172`, pattern unique, chroot run silent; 2026-11-08 |
| the same patch at load leaves the file unchanged | [m] | `LD_PRELOAD` constructor, same sha256 before and after |
| the shell domain cannot `chroot` or `unshare -Ur` | [m] | uid 2000, `Seccomp: 0`: `chroot` exit 125, `unshare` exit 1, on Android 10, 12 and 15, 2026-11-08 |
| root can `chroot`, and still cannot create a user namespace | [m] | Magisk, Android 15: `chroot / /system/bin/true` ok; `unshare -Ur true` says `Invalid argument`, 2026-11-08 |
| a rooted phone's boot partition is 64 MB in total | [m] | `blockdev --getsize64` on the S21 FE, 2026-11-08 |
| a minimal FHS tree runs under `chroot` on a rooted phone | [m] | one static busybox, 359 applets, 1721 KB; `uid=0`, `/proc` readable, `/system` absent, 2026-11-08 |
| applet symlinks must be relative inside a chroot | [m] | absolute links gave `exec /bin/sh: No such file or directory`; `ln -sfn busybox sh` fixed it |
| a dynamic glibc program runs under `chroot`, no shim, no tracer | [m] | a 2.1 MB tree (`dash` + `libc.so.6` + loader); `Debian GLIBC 2.41` reported from inside, 2026-11-08 |
| an unexecutable loader is `EACCES`, not `ENOENT` | [m] | loader at 0644: `exec /bin/sh: Permission denied`; at 0755 it runs - the trap `adb push` sets |
| `CapEff` is `0` in the shell domain and full as root | [m] | `0000003fffffffff` as root against `0` as uid 2000, 2026-11-08 |

## What is deliberately not claimed

- **A universal speed-up.** Every performance number here is one device, one
  date, one workload mix.
- **Coverage of "all of Debian".** Coverage claims are made against a named
  package set — a base tree plus a compiler, `git`, Python — not against the
  archive.
- **A musl program or package.** Alpine shares the model and none of these
  measurements; it is out of
  [scope](../README.md#the-methods-side-by-side).
- **Isolation.** A tree is a compatibility layer. Programs in it share one real
  uid and can read each other's files. If you need isolation, the answer is a
  VM ([AVF](https://source.android.com/docs/core/virtualization) on modern
  devices), not this.

## Reproducing

1. `examples/probe.sh` on the phone — the platform facts for *your* device.
2. [a glibc userland](../tree/glibc.md) — build one, then try `apt-get install figlet`.
3. [a bionic-native tree](../tree/bionic.md) — build one from what the phone has,
   then [root](../tree/durability.md) for whether it comes back.
4. [measurement](./measure.md) — measure it, and write the six fields down.

If your result contradicts a table here, that is the most useful bug report this
repository can get. [CONTRIBUTING.md](../CONTRIBUTING.md) says what to include.

## Colophon

The measurements come from a runtime whose design notes, investigation log and

The measurements come from a runtime whose design notes, investigation log and
per-syscall evidence run to tens of thousands of lines, and from a durable
host-material tree that has been running in production on two phones. This guide
is the part that survives translation to another device. It is self-contained:
code appears inline, and nothing here requires another repository.

