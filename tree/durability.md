# Where the tree lives, and whether it comes back

The tree is a device, not a session. Where its files are decides what it survives
— and the answer is not a matter of taste.

## The ladder

| where the files are | survives a reboot | survives a factory reset | use it for |
| --- | --- | --- | --- |
| RAM (`tmpfs`) | no | no | scratch, sockets, locks |
| app private data | yes | no | a product's payload |
| `/data/local/tmp` | yes | no | rootless trees, test payloads |
| `/data/adb` | yes | no | the live tree, modules, state |
| **the boot ramdisk (`overlay.d`)** | yes | **yes** | the tree's **source**, boot scripts, rescue hooks |
| `system` / `vendor` | yes | yes | nothing you own: an OTA replaces it |

Reset clears `/data`, not `boot`. So a reset is survivable only if the thing that
**restores** `/data` lives in `boot` — which is why the durable tree is the small
one ([the host's own material](bionic.md)), and a glibc tree is restored *by* it
rather than living in it.

## Two levels, and you must say which

- **survives a reboot**: `/data` — settings, `pm` state, `/data/adb`, `/data/misc/adb/adb_keys`.
- **survives a factory reset**: outside `/data` — the boot ramdisk, and the modem
  partition for radio configuration.

"Durable" without a level is an incomplete sentence. Each feature declares its
level and its test: reboot without touching the phone; for the reset level,
remove that feature's `/data` state and reboot without touching it.

## The boot-image frame

Distilled from a tree that survived a simulated reset [m]:

1. **Where**: `overlay.d/` in the patched boot ramdisk; the rooting tool splices
   its rc into `init.rc` and copies `overlay.d/sbin/*` into `$MAGISKTMP` in every
   boot mode.
2. **Activation**: an init trigger, e.g. `on property:sys.boot_completed=1`, running
   `exec_background u:r:magisk:s0 0 0 -- /system/bin/sh $MAGISKTMP/<name>.sh`. Do not
   use `exec_background` for a long-lived supervisor: init kills the process group
   when the script returns — use an init service instead.
3. **Restore by version**: keep the tree's source as a tarball plus a version
   file; on boot, compare the live tree's version, extract when missing or
   different, and preserve the few files that must survive (keys, passwords).
4. **Only official mechanisms** (`svc`, `settings`, `cmd`, `pm`) and nothing that can
   break the boot; idempotent, because it runs every boot.
5. **Log to the kernel**: `echo "<name>: ..." > /dev/kmsg`; read the session in
   `dmesg` and the previous boot in `/proc/last_kmsg`. A userland log on a broken
   system is no log.
6. **Build and verify the image independently**: unpack, add, repack, then check
   the kernel is unchanged, every added file's hash matches the repository, and
   the AVB footer is present — before anything is written.
7. **Test by simulating the reset for that feature only**: remove its `/data`
   state, reboot, touch nothing. A platform package change has a delayed write
   ([m] about 30 s), so a reboot sooner than that tests nothing.

The reference device leaves about 34 MB free in the boot partition after a 29 MB
kernel [m], which is the constraint that decides what may live there: scripts and
one small tarball, not a distribution.

## Unattended

Running without a human is a consequence of the tree being a platform, not a
separate feature: it adds a rescue path (ADB and a web face, on the plane that
does not need the framework), a restart budget, and idempotency to everything
that runs at boot. The useful decomposition is five rungs — start, reach, safety
net, staged healing, observe — each working with the rung above it broken.
