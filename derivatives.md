# Derivatives

A derivative applies a method, recipe or execution-domain profile from this
guide. The [isolation level](README.md#the-isolation-scale) describes the
execution path. The [domain](reference/domains.md) describes whose permissions
the process has.

| project | what it builds | FOA basis | level and domain | validation |
| --- | --- | --- | --- | --- |
| [deb-native](https://github.com/jronminh/deb-native) | Rootless Debian arm64 developer tree and runtime [s] | [glibc supply](tree/glibc.md), [tracer](methods/tracer.md), [loader shim](methods/loader.md), [exec](methods/exec.md), [identity](methods/identity.md), [ADB recipe](recipes/no-root-glibc.md) | **3**, with level **2** in-process mechanisms. App for Termux or an APK host, shell for the ADB build [s]. | ADB package install measured on Galaxy S10e, Android 12, 2026-10-18 [m]. A minimal glibc tree ran on Sharp 701SH, Android 10, 2026-11-06 [m]. Full Android 16 prefix validation is open [u]. [ADB host record](https://github.com/jronminh/deb-native/blob/main/docs/spec/adb-host.md) |
| [open-android-router](https://github.com/jronminh/open-android-router) | Android management and router commands with a BusyBox web UI [s] | [scripts](methods/scripts.md), [BusyBox farm](recipes/busybox-farm.md), [service verbs](recipes/service-verbs.md), [supervisor](recipes/supervisor.md), [host tree deploy](recipes/host-tree-deploy.md) | **0**, shell or Magisk root [s]. | Deploy and check passed with SELinux enforcing on Sharp 701SH, Android 10, in shell and Galaxy S21 FE, Android 15, as root. Galaxy S10e, Android 12, passed in shell with SELinux permissive. All three runs were on 2026-11-08 [m]. Android 6–9 is a target [u]. [Support record](https://github.com/jronminh/open-android-router/blob/main/docs/SUPPORT.md#verified-devices) |
| [pyrunner](https://github.com/jronminh/pyrunner) | An APK that opens Python scripts in a console using bundled bionic CPython and a PTY [s] | [patch package](methods/patch-package.md), [bundle](recipes/bundle.md), [terminal](reference/mechanisms.md#a-terminal) | **1**, app. The build sets `$ORIGIN` and the app starts the interpreter from its installed native-library directory [s]. | APK build and launch path checked in source [s]. A dated device run of the PTY path is open [u]. |
| [termux-adb-bridge](https://github.com/jronminh/termux-adb-bridge) | A Termux client and a native daemon that runs requested commands under the ADB shell UID [s] | [scripts](methods/scripts.md), [shell-UID daemon](methods/shell-uid-daemon.md) | **0** for the shell command path. The client stays in the app domain and the daemon runs in shell [s]. | Project documentation gives command and refusal outputs [s]. Device model and Android version are absent from that record [u]. |
| [miband9-direct](https://github.com/jronminh/miband9-direct) | A Termux backend and CLI for the Xiaomi Smart Band 9 Active, with a shell-side BLE transport [s] | [host material](tree/bionic.md), [execution domains](reference/domains.md), [framework GATT](reference/devices.md#what-it-means-for-a-tree), [shell-UID daemon launch and pairing](methods/shell-uid-daemon.md) | **0** for the transport. Backend in app, `app_process` transport in shell [s]. | GATT connection measured on Galaxy S23 FE, Android 16, 2026-09-18 [m]. The installer uses on-device ADB to launch the detached BLE transport [s]. [Transport probe](https://github.com/jronminh/miband9-direct/blob/44896aedf740a8afa721426ea0b99025065d99ee/docs/SPIKE.md), [installer](https://github.com/jronminh/miband9-direct/blob/44896aedf740a8afa721426ea0b99025065d99ee/install.sh), [launcher](https://github.com/jronminh/miband9-direct/blob/44896aedf740a8afa721426ea0b99025065d99ee/daemon/start.sh) |

## How a derivative cites FOA

Add a visible `Built on FOA -> <page>, level N` line to the derivative README.
Link the page to the primary FOA method or recipe at a full commit SHA. In
`refs/foa.md`, record that SHA, the page paths and heading slugs, execution
domain, level, local differences and validation. Advance the pin and update the
validation note after reviewing the relevant FOA changes.
