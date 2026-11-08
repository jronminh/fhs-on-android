# An FHS root that runs a static binary

**Goal.** A directory that is `/` for the programs inside it, with no shim and no
tracer, running one static binary. **Isolation 4.**

**Tested on.** Galaxy S21 FE, Android 15 (sdk 35), kernel 5.4.242, Magisk root,
2026-11-08 [m].

**Prerequisites.**

- root (`su -c` answering `uid=0`);
- a **static** busybox: `readelf -l BUSYBOX | grep -c interpreter` must print 0.
  A rooting tool ships one, usually at `/data/adb/magisk/busybox`;
- about 2 MB free.

**Time and size.** A minute. 1.7 MB, 359 applets (busybox 1.36).

**Steps.**

1. Build the layout and copy the binary:

   ```sh
   TREE=/data/adb/fhs-tree
   BB=/data/adb/magisk/busybox
   mkdir -p "$TREE"/{bin,etc,tmp,proc,sys,dev}
   cp "$BB" "$TREE/bin/busybox"; chmod 755 "$TREE/bin/busybox"
   ```

2. Make the applets **relative** links:

   ```sh
   cd "$TREE/bin" && "$TREE/bin/busybox" --list | while read -r a; do ln -sfn busybox "$a"; done
   ```

3. Give it the files a login expects:

   ```sh
   printf 'root:x:0:0:root:/root:/bin/sh\n' > "$TREE/etc/passwd"
   printf 'root:x:0:\n' > "$TREE/etc/group"
   chmod 1777 "$TREE/tmp"
   ```

4. Bind the kernel filesystems:

   ```sh
   mount -t proc proc "$TREE/proc"
   mount -t sysfs sysfs "$TREE/sys"
   mount -o bind /dev "$TREE/dev"
   ```

5. Enter:

   ```sh
   chroot "$TREE" /bin/sh -c 'PATH=/bin; id; uname -r; ls /'
   ```

**Expected.**

```
uid=0(root) gid=0(root)
5.4.242-30976065-abG990EXXUDGYD4
bin dev etc proc sys tmp
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `chroot: exec /bin/sh: No such file or directory`, and `/bin/sh` exists | the applet links are absolute, naming the tree's path from outside | `readlink "$TREE/bin/sh"` must be `busybox` |
| `mount: Permission denied` | not root in that shell | `id -u` from the same shell |
| busybox itself refuses to run | it is dynamic, not static | the `readelf` check above |
| `rm -rf` says `Device or resource busy` | the `/dev` bind is still mounted, with its submounts | `umount -l` it, `mount | grep`, then delete — never delete first |

**Undo.**

```sh
umount -l "$TREE/dev"; umount "$TREE/sys"; umount "$TREE/proc"
mount | grep -q "$TREE" && { echo "still mounted: stop"; exit 1; }
rm -rf "$TREE"
```

**Cost.** Inside, `/system`, `/data` and every Android service are out of reach:
`ls /system` answers `No such file or directory` [m]. That is what level 4 provides
and what it removes ([root](../tree/root.md)).
