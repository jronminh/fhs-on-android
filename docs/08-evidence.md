# 8. Evidence

This guide exists because a lot of "Linux on Android" writing states platform
facts that are not true on the reader's phone. The defence is a device table and
a label on every claim.

## Devices

| device | Android | kernel | hosts used | role |
| --- | --- | --- | --- | --- |
| Samsung Galaxy S10e (SM-G970W) | 12 | 4.14.190 | Termux, `adb shell` | the main measurement device; all numbers in [06](06-measure.md) |
| Sharp 701SH (SDM660, 3 GB) | 10 | 4.4.205 | `adb shell` | oldest kernel in the set; where "it works on 4.4 too" was checked |
| Samsung Galaxy S23 FE | 16 | — | Termux | builds an APK host, and the second-generation runtime target |
| Samsung Galaxy S21 FE (SM-G990E) | 15 | — | root (Magisk) | the M1 comparison point and a non-FHS busybox tree; not used for path-layer claims |

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
| a dynamic ELF fails before `main` when `PT_INTERP` is unresolvable, with `ENOENT` | [s] | ELF and `ld.so` semantics; reproducible in five minutes ([03](03-build-a-tree.md#experiment-first-three-failures-in-five-minutes)) |
| an app-domain process can be killed by a seccomp `TRAP` (`SIGSYS`) where the `adb shell` domain has none | [m] | `Seccomp:` in `/proc/self/status`: `0` for uid 2000, non-zero in the app domain |
| no `CAP_SYS_ADMIN` in either domain, so `mount`/`chroot` fail | [m] | `CapEff` in `/proc/self/status`, plus the syscalls themselves |
| `execve` of app data is refused at `targetSdk ≥ 29` | [s] | the platform's SELinux policy (`untrusted_app`), and the failure mode when an app is lifted above 28 |
| a tree at native speed is reachable without root | [m] | the numbers in [06](06-measure.md); 1.3–1.6× on the workloads listed |
| the same tree boots on a 4.4 kernel | [m] | Sharp 701SH, 2026-11 |
| proot's cost is "large on metadata, small on CPU" | [u] | widely reported; **this project has not measured it**. Measure before quoting |
| user namespaces are usually unavailable | [u] | reported per device; the only honest form is `unshare -Ur` on your phone ([examples/probe.sh](../examples/probe.sh)) |
| a 16 KB-page device breaks 4 KB assumptions | [s]/[u] | the platform documents 16 KB; the exact failure per build system is untested here |
| a high-`targetSdk` APK runtime with userland exec works | [u] | it is a design ([07](07-prior-art.md)), not a shipped result |

## What is deliberately not claimed

- **A universal speed-up.** Every performance number here is one device, one
  date, one workload mix.
- **Coverage of "all of Debian".** Coverage claims are made against a named
  package set — a base tree plus a compiler, `git`, Python — not against the
  archive.
- **Isolation.** A tree is a compatibility layer. Programs in it share one real
  uid and can read each other's files. If you need isolation, the answer is a
  VM ([AVF](https://source.android.com/docs/core/virtualization) on modern
  devices), not this.

## Reproducing

1. `examples/probe.sh` on the phone — the platform facts for *your* device.
2. [03](03-build-a-tree.md) — build a tree, run the three bars.
3. [06](06-measure.md) — measure it, and write the six fields down.

If your result contradicts a table here, that is the most useful bug report this
repository can get. [CONTRIBUTING.md](../CONTRIBUTING.md) says what to include.

## Colophon

The measurements come from a runtime whose design notes, investigation log and
per-syscall evidence run to tens of thousands of lines; this guide is the part
that survives translation to another phone. Where the underlying work is public
it is linked: [deb-native](https://github.com/jronminh/deb-native) (runtime,
GPL-3.0) and its `docs/performance.md`.
