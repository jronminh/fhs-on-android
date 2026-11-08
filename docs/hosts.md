# 7. Hosts

A **host** is who runs the tree. The same tree behaves differently in each
domain, and the differences are not cosmetic — they decide whether Gate A
exists, whether `execve` of the tree is legal, how long the tree can stay up,
and whether it can come back at all.

This page compares the four domains. Pick the host first; the method
([methods](methods.md)) follows from it, and for root the durability work
follows too ([root](root.md)).

## Termux

You are `u0_aNNN`, inside an app, with the app's seccomp filter and the app's
data directory.

- **Gives** an equipped environment (`clang`, `python`, `debootstrap`, `git`),
  a package manager for the host side, storage access, and an easy way to build
  the tree on the device itself.
- **Takes** the app sandbox: Gate A is present, so any syscall the app filter
  traps kills the process unless something catches the signal. Termux itself
  ships at `targetSdk 28` [s] — that is what makes running binaries out of its
  data directory legal at all, and it is a clock, not a design.
- **Fits** building a tree, experimenting, and anything interactive.
- **Does not fit** a service that must survive Termux being killed, and anything
  that needs a real `/data` path.

## A custom APK

You own the app: its `targetSdk`, its manifest, its service.

- **Gives** a terminal UI, an icon, a foreground service that keeps the session
  alive, and the ability to ship the tree as an asset. This is the only host a
  normal user can install.
- **Takes** the same sandbox as Termux, plus a hard platform rule:

  | `targetSdk` | `execve` of a file in app data | `execmod` for shim patches |
  | --- | --- | --- |
  | ≤ 28 | allowed (`untrusted_app_27`) | allowed |
  | ≥ 29 | **refused** | restricted |

  `targetSdk 28` is an escape hatch that will not survive a store listing or a
  long-lived product. The way through is **userland exec** (M7): ship the
  runtime as APK native libraries and never ask the kernel to `execve` app data.
- **Fits** the end-user product; needs the most work.
- **Costs** an APK build pipeline (`aapt2`, `d8`, `apksigner` — no Gradle
  required), a signing key you must not lose, and the tree as an asset (50–100 MB
  compressed, not in git).

## `adb shell`

You are `2000(shell)` with no app, a prefix under `/data/local/tmp`, driven from
a PC.

- **Gives** the easiest domain on the phone: `Seccomp: 0` [m], so there is no
  Gate A at all; `execve` of your own files is fine; `/data/local/tmp` survives
  reboots and app updates; no zip, no asset, no signing.
- **Takes** reachability: you need a cable or wireless debugging. And a lifetime
  rule — a process started in the debug-bridge domain does not outlive the
  `adbd` that started it [m]. Restarting `adbd` (which a USB function change
  does) kills the tree, so a long-running service needs a re-attach loop from
  the PC side, not a daemon inside the phone.
- **Fits** servers, cluster nodes, CI on a phone, anything headless. It is the
  best domain for measuring, because nothing of the app sandbox is in the way.
- **Does not fit** a product for other people: nobody installs a phone that
  needs `adb`.

## root (Magisk and similar)

A different contract: you can `chroot` and bind-mount (M1), run services from
`init`, and — the part that matters more than either — put the tree's source in
the **boot image**, the only place a factory reset does not reach.

- **Gives** real uid 0, real mounts, `tun`, raw sockets, softap, ports below
  1024, a writable kernel log, and durability.
- **Takes** the unlock (attestation, some vendor features), OTA freedom on
  devices whose next release removes unlocking, and the responsibility for
  anything your boot scripts do.
- **Fits** a device you own and must keep alive: a router, a node, an uplink.
- **Costs** the whole discipline in [root](root.md): the durability ladder, the
  boot-image frame, and a rescue path that does not depend on the phone booting.

## Comparison

| | Termux | custom APK | `adb shell` | root |
| --- | --- | --- | --- | --- |
| uid | app `u0_aNNN` | app `u0_aNNN` | `2000(shell)` | 0 |
| Gate A (app seccomp) | yes | yes | **no** | no |
| `execve` of the tree | only at `targetSdk` ≤ 28 | same | yes | yes |
| real `chroot`/`mount` | no | no | no | yes |
| tree location | app data | app data | `/data/local/tmp` | anywhere |
| survives reboot | if the app starts it | if a service starts it | yes (file), not as a process | yes |
| survives a **factory reset** | no | no | no | **yes, from the boot image** |
| survives `adbd` restart | yes | yes | **no** | yes |
| usable by a normal user | yes | yes | no | no |
| GUI (X11/Wayland) | with a separate app | the same app | not practical | yes |
| best for | building, experimenting | the product | headless, measuring | lab devices |

## What the host must supply

The tree cannot know about Android, so the host answers four questions for it:

1. **the session** — a pty, `HOME`, `PATH`, `TMPDIR`, a terminal size, and an
   answer to "who am I" (`/etc/passwd` line, `USER`, `LOGNAME`);
2. **boot inputs** — where the tree is, which binds to map, which host variables
   to keep (`ANDROID_ROOT`, `ANDROID_DATA`, `EXTERNAL_STORAGE`, locale);
3. **Android services the tree cannot reach** — DNS (the resolver is `netd`),
   clipboard, notifications, and later display/input/audio;
4. **the device nodes the app domain may open** — for a terminal, almost none;
   for a GUI, everything becomes a device-table problem ([limits](limits.md)).

Keeping those four in the host, and out of the path rule, is what makes one
runtime serve four hosts instead of four runtimes.

## How to tell which domain you are in

From inside a shell, without trusting the prompt:

```sh
id -u                                              # 2000 = adb, 10xxx = app
grep Seccomp /proc/self/status                     # 0 = no app filter
cat /proc/self/attr/current                        # SELinux domain, e.g. untrusted_app_27
ls -ld /data/local/tmp                             # writable and executable for 2000
getprop ro.build.version.sdk                       # decides execve and 16 KB pages
```

[examples/probe.sh](../examples/probe.sh) collects these, plus the capability
set, the page size and a set of "does this actually work" tests, in one
read-only run.
