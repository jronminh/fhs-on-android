# A tree that survives a factory reset

**Goal.** The tree's **source** in the boot ramdisk, restored at every boot, so a
factory reset brings the tree back. This is about durability, not isolation.

**Recorded.** A Magisk-rooted Samsung phone, Android 15, 2026-11-07 [m, recorded]:
the source was placed in `overlay.d`, the tree was removed from `/data`, the phone
rebooted, and the tree came back with its keys. **Not re-run for this repository.**

**Prerequisites.** root, `magiskboot`, a PC with a copy of the stock firmware, and
a tree small enough: the boot partition had 34 MB free after a 29 MB kernel on the
reference device. The source is a compressed tarball plus a version file, not the
tree.

**Time and size.** Half an hour, mostly verification. A few hundred kilobytes added.

**Steps.**

1. Pull the current boot image and keep it:

   ```sh
   adb shell 'su -c "dd if=/dev/block/by-name/boot of=/data/local/tmp/boot.img"'
   adb pull /data/local/tmp/boot.img backup/boot-original.img
   sha256sum backup/boot-original.img
   ```

2. Unpack, add the files, repack:

   ```sh
   magiskboot unpack boot.img
   magiskboot cpio ramdisk.cpio "add 0644 overlay.d/tree.rc tree.rc" \
                                   "add 0755 overlay.d/sbin/tree.sh tree.sh" \
                                   "add 0644 overlay.d/sbin/tree.tar.gz tree.tar.gz"
   magiskboot repack boot.img new-boot.img
   ```

3. Verify before writing: the kernel is unchanged, every added file's hash matches,
   and the AVB footer is present.

4. Write it, read it back, compare hashes, then boot.

5. Test the reset for that feature only:

   ```sh
   adb shell 'su -c "rm -rf /data/adb/tree"'
   adb reboot
   # touch nothing; after boot:
   adb shell 'su -c "ls /data/adb/tree/bin | head"'
   ```

**Expected.** After the reboot, the tree's directory exists again and its version
file matches the one packed into the image; the log line from the boot script is
in `dmesg` for this boot, and in `/proc/last_kmsg` for the previous one.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| the overlay is gone after a rooting-tool update | "direct install" rebuilds the boot image | re-add the overlay in the same session |
| the phone does not boot | a boot hook that hangs, or a bad repack | flash the saved original image from a PC |
| the tree is restored but stale | the version comparison used a file the boot never writes | make the comparison total: missing means restore |
| a package change is undone after a reboot | the platform writes package state with a delay | wait about 30 s after the change before rebooting |

**Undo.** Flash `backup/boot-original.img`, then `adb shell 'su -c "rm -rf /data/adb/tree"'`.

**Cost.** The boot image is the one place where a mistake needs a PC to fix; the
rest of the frame exists for that reason ([the boot-image frame](../tree/durability.md#the-boot-image-frame)).
