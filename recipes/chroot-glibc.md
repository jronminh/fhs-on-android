# An FHS root that runs a dynamic glibc program

**Goal.** The same root as the busybox recipe, but for a program linked against
glibc: the loader, the libc, one shell. **Isolation 4.**

**Tested on.** Galaxy S21 FE, Android 15 (sdk 35), kernel 5.4.242, Magisk root,
2026-11-08 [m].

**Prerequisites.**

- root, and a glibc userland to take three files from: `usr/bin/dash`,
  `usr/lib/aarch64-linux-gnu/libc.so.6` and
  `usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1`. If you have none,
  [ingredients-debian](ingredients-debian.md) builds one on a Linux host in about
  a minute;
- about 3 MB free.

**Time and size.** A minute. 2.1 MB.

**Steps.**

1. Copy the three files into the tree's own paths:

   ```sh
   TREE=/data/adb/glibc-tree; SRC=/path/to/the/prefix
   mkdir -p "$TREE"/{bin,etc,tmp,proc,sys,dev} "$TREE/lib/aarch64-linux-gnu"
   cp "$SRC/usr/bin/dash" "$TREE/bin/dash"; chmod 755 "$TREE/bin/dash"; ln -sfn dash "$TREE/bin/sh"
   cp "$SRC/usr/lib/aarch64-linux-gnu/libc.so.6" "$TREE/lib/aarch64-linux-gnu/"
   cp "$SRC/usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1" "$TREE/lib/aarch64-linux-gnu/"
   ```

2. Make the loader executable, and give it the name the programs ask for:

   ```sh
   chmod 755 "$TREE/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1"
   ln -sfn aarch64-linux-gnu/ld-linux-aarch64.so.1 "$TREE/lib/ld-linux-aarch64.so.1"
   ```

3. Bind the kernel filesystems, then run the loader itself first:

   ```sh
   mount -t proc proc "$TREE/proc"
   mount -t sysfs sysfs "$TREE/sys"
   mount -o bind /dev "$TREE/dev"
   chroot "$TREE" /lib/ld-linux-aarch64.so.1 --version | head -n 1
   chroot "$TREE" /bin/sh -c 'echo "math: $((6*7))"; [ -d /system ] && echo present || echo "system: absent"'
   ```

**Expected.**

```
ld.so (Debian GLIBC 2.41-12+deb13u4) stable release version 2.41.
math: 42
system: absent
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `exec /bin/sh: No such file or directory` | the loader is missing, or the `/lib/ld-linux-aarch64.so.1` link is not there | `ls -l "$TREE/lib/"` |
| `exec /bin/sh: Permission denied` | the loader exists but is not executable; `adb push` writes 0644 and `cp` keeps it | `ls -l` the loader, then `chmod 755` |
| `error while loading shared libraries` | `libc.so.6` is not under `lib/aarch64-linux-gnu` | the exact path the loader searches |

**Undo.**

```sh
umount "$TREE/dev"; umount "$TREE/sys"; umount "$TREE/proc"
rm -rf "$TREE"
```

**Cost.** As with the busybox recipe, Android is out of reach inside, and the tree
is only as complete as the files copied into it. A package manager needs a full
userland, which is the sketch in [the index](README.md#sketches-not-recipes-yet).
