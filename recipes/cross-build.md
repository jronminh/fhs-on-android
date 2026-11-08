# Build a program for the tree on the host

**Goal.** Compile a program on a Linux host for the phone's architecture, then run
it inside the tree. **Isolation 1** in general, **0** inside a chroot where the
tree's loader is already at `/lib/ld-linux-aarch64.so.1`.

**Tested on.** Debian 13 (WSL 2) for the build; Galaxy S21 FE, Android 15, kernel
5.4.242, Magisk root, 2026-11-08 for the run [m].

**Prerequisites.** a host with `gcc-aarch64-linux-gnu` (`apt-get install
gcc-aarch64-linux-gnu`, about a minute); a tree on the phone
([debian-chroot-full](debian-chroot-full.md) or [chroot-glibc](chroot-glibc.md)).

**Time and size.** Under a minute. The binary is 70 KB.

**Steps.**

1. Write the program:

   ```c
   #include <stdio.h>
   #include <unistd.h>
   #include <sys/utsname.h>
   int main(void) {
       struct utsname u;
       if (uname(&u) == 0) printf("kernel: %s\n", u.release);
       printf("uid: %d\n", (int)getuid());
       return 0;
   }
   ```

2. Build it for `aarch64` and check what it asks for:

   ```sh
   aarch64-linux-gnu-gcc -O2 -o hello hello.c
   file hello        # ELF 64-bit ... ARM aarch64, interpreter /lib/ld-linux-aarch64.so.1
   ```

3. Put it in the tree and run it with a clean environment:

   ```sh
   adb push hello /data/adb/trixie-arm64/root/hello
   adb shell 'su -c "chmod 755 /data/adb/trixie-arm64/root/hello"'
   adb shell 'su -c "chroot /data/adb/trixie-arm64 /usr/bin/env -i PATH=/usr/bin:/bin HOME=/root TMPDIR=/tmp /root/hello"'
   ```

**Expected.**

```
kernel: 5.4.242-30976065-abG990EXXUDGYD4
uid: 0
built on a different machine
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `Exec format error` | the binary is for another architecture | `file` it, or `readelf -h` |
| `No such file or directory` although the file is there | the interpreter in `PT_INTERP` is not in the tree | `readelf -l` and `ls` that path |
| `version 'GLIBC_2.xx' not found` | built against a newer libc than the tree's | build with an older toolchain, or in the tree |
| a missing `.so` at start | the program needs a library the tree lacks | `apt-get install` the package in the tree |

**Undo.** `adb shell 'su -c "rm -f /data/adb/trixie-arm64/root/hello"'`

**Cost.** A cross-built program is tied to the tree's loader path and to its libc
version; rebuild it when either moves ([rebuild](../methods/rebuild.md)).
