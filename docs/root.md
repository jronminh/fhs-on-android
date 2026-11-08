# 6. Root

Root is not the next item on a list of methods. It is a different contract with
the device: what you may do, and — the part people miss — **where you may put
things so that they survive**.

The two questions are separate. A rooted phone lets a foreign tree run under
`chroot` ([methods](methods.md#m1--root-chroot-and-bind-mounts)); a rooted phone
also lets a tree live in the boot image. The second is the more interesting one,
and it is why a *poor-host* tree is often the right answer even when you have
root.

## What root buys

| capability | gate removed | what it makes possible |
| --- | --- | --- |
| real uid 0 | B ([the three gates](the-problem.md#the-three-gates)) | real `chown`, real setuid, `su`; a tree that no longer has to lie about identity |
| `CAP_SYS_ADMIN` | B | `mount`, `chroot`, `unshare`; a foreign tree with no path layer at all |
| `CAP_NET_RAW` | B | `ping`, raw sockets, packet capture |
| `CAP_NET_BIND_SERVICE` | B | ports below 1024 (a web UI on `:80`) |
| `/dev/net/tun` | B / C | userspace VPN (wireguard-style) on the device |
| softap control (`cmd wifi start-softap`) | B | a real hotspot from the tree [m] |
| `svc data` | B | mobile data on/off (it hangs for uid `shell`) [m] |
| writable `/dev/kmsg` | C | a log sink that survives a dead app layer, readable in the *next* boot from `/proc/last_kmsg` [m] |
| systemless `hosts` | C | a friendly name through the tether's DNS [m] |
| **the boot image** | — | the only place that survives a factory reset |

## What root costs

- **The unlock is one-way in practice.** Warranty attestation (Knox on Samsung)
  trips; some vendor releases later remove unlocking entirely, which turns "do
  not take the next OTA" into a permanent obligation, and makes OTA blocking a
  boot-critical feature rather than a preference [m].
- **The boot image is a fragile artifact.** Re-running the rooting tool's
  "direct install" regenerates `boot` and silently drops your overlay. Never
  flash a single partition from a full firmware package. Keep the stock firmware
  and a known-good image, with checksums, on a PC.
- **A bug at boot is unrecoverable without a PC.** A script that changes the USB
  gadget and hangs has taken the only network path with it. That is why the
  frame below insists on idempotency, a restart budget and an independent access
  path.
- **You now own the phone's security posture.** SELinux stays enforcing, but you
  are running shell scripts as root at every boot; treat the tree as part of the
  trusted computing base.

## The durability ladder

| where the files are | survives reboot | survives a factory reset | wiped by an app update | use it for |
| --- | --- | --- | --- | --- |
| RAM (`tmpfs`, `/dev/shm`) | no | no | — | scratch, sockets, locks |
| app private data | yes | no | uninstall wipes it | a product's payload |
| `/data/local/tmp` | yes | no | no | rootless trees, test payloads |
| `/data/adb` (Magisk modules, `service.d`) | yes | no | no | the live tree, modules, state |
| **`boot` ramdisk, `overlay.d`** | yes | **yes** | — (until Magisk is reinstalled) | the tree's **source**, boot scripts, the rescue hooks |
| `system` / `vendor` | yes | yes | **OTA replaces it** | nothing you own |

The ladder says what the boot image is *for*: not the tree itself, but the
**source** of the tree and the scripts that put it back. Reset clears `/data`,
not `boot`; so a reset is survivable only if the thing that restores `/data`
lives in `boot`.

**Size is the constraint that decides the design.** On the reference device the
boot partition has roughly 34 MB free after a 29 MB kernel [m]. A 260 MB Debian
tree cannot go there; a few hundred kilobytes of scripts and one compressed
source tarball can. This is the mechanical reason the durable tree is the
poor-host one, and the foreign tree is restored *by* it rather than living in
it.

## The boot-image frame

Distilled from a tree that has survived a simulated factory reset [m]:

1. **Where.** `overlay.d/` in the patched boot ramdisk. The rooting tool splices
   its rc into `init.rc` and copies `overlay.d/sbin/*` into `$MAGISKTMP`
   (`/debug_ramdisk`) in every boot mode.
2. **Activation.** An init trigger in `<name>.rc`, e.g.
   `on property:sys.boot_completed=1`, running
   `exec_background u:r:magisk:s0 0 0 -- /system/bin/sh ${MAGISKTMP}/<name>.sh`.
   Do not use `exec_background` for a long-lived supervisor unless you accept
   that init kills the process group when the script returns.
3. **What it may do.** Only the framework's own mechanisms (`svc`, `settings`,
   `cmd`, `pm`) and things that cannot break the boot: no `iptables` games, no
   `configfs` archaeology, no assumption that a setting written last boot is
   still true.
4. **Idempotent.** Check before changing: do not reset a USB gadget whose
   function set is already correct.
5. **Self-sufficient.** No Magisk app, no `su` binary after a reset: the script
   runs directly from init in the `magisk` domain.
6. **Log to the kernel.** `echo "<name>: ..." > /dev/kmsg`; read it in the
   session with `dmesg`, and read the *previous* boot from `/proc/last_kmsg`.
   A userland log on a broken system is no log.
7. **How to write it.** `dd` the boot partition out, unpack, `cpio add`,
   repack, then verify independently — kernel, the added files, the AVB footer —
   save image + sha256, write it, read it back, and only then test.
8. **How to test it.** Simulate the reset for *that feature only*: remove its
   `/data` state, reboot, touch nothing. If the feature returns by itself, the
   boot frame is correct.

## The state rule, again

Two kinds of state ([two kinds of tree](two-kinds-of-tree.md#the-second-axis-state)),
and the boot frame adds the discipline:

- the platform's state is **re-applied at every boot** through official calls;
- the owner's intent lives in a file in the tree, so a human can read and change
  it without a UI;
- nothing keeps a copy of the platform's answer.

Two concrete consequences from the reference device: package state has a delayed
write, so a reboot within ~30 s of a `pm` change tests nothing [m]; and CE
storage stays unlocked at boot only because there is no lock screen — set one,
and the boot scripts run later or not at all.

## The headless ladder

A machine you cannot see needs more than a root shell. The useful decomposition
is five rungs, each answering a failure mode of the rung above:

| rung | answers | example |
| --- | --- | --- |
| **L0 start** | nobody will press power | boot on charger insertion, with a battery threshold |
| **L1 reach** | one path is not enough | USB ADB + TCP ADB + a second SSH daemon + an overlay network |
| **L2 safety net** | an experiment can strand it | a boot counter that disables the lab module after N failed boots; an emergency flag file |
| **L3 staged healing** | the network or radio is wedged | check → reset route → toggle airplane → restart radio → restart; with a restart budget (~3/hour) and a "stay still and keep a path" fallback |
| **L4 observe** | you cannot see it | rotating logs, a heartbeat to a second machine, the previous boot's kernel log |
| **L5 rescue** | it is truly dead | the stock firmware and a flasher on a PC, and a documented way into Download mode |

The order is the point: every rung must work with the rung above it broken.

## Which parts survive a broken framework

Root buys a second plane, and the two planes fail independently. Measured on two
generations of Android [m]:

| tool | implementation | needs `system_server`? |
| --- | --- | --- |
| `cmd`, `dumpsys`, `logcat`, `getprop`, `service` | native binaries | no |
| `settings`, `pm` | shell wrapper over `cmd` | no |
| `am` (except `am instrument`) | shell wrapper over `cmd` | no |
| `content` | `app_process content.jar` | **yes, every call** |
| `svc` | Android 10: `app_process svc.jar`; Android 15: wrapper over `cmd` | 10: yes · 15: no |

So a broken `system_server` takes SMS reads, some `svc` verbs and every `cmd`
call with it, while ADB, the shell tree, a static SSH daemon and iptables keep
working. Design the rescue path on the plane that does not need ART.

## Two traps worth memorising

- **Re-installing the rooting tool wipes the overlay.** "Direct install"
  regenerates `boot`. If the tree's source lives there, the tree is now one
  reboot away from vanishing. Re-add the overlay in the same session.
- **You cannot use the vendor's own management surface once Knox trips.**
  Device-owner apps and some vendor policy APIs are gone [m]; the tree is the
  management surface. Plan for that before unlocking, not after.
