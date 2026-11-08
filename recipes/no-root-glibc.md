# A glibc tree with no root, over adb

**Goal.** A glibc userland in `/data/local/tmp`, entered from a PC over `adb shell`
with no root. **Isolation 1–3**, depending on the runtime used to start it.

**Recorded.** Galaxy S10e, Android 12, 2026-10-18 [m, recorded]. **Not re-run for
this repository**, and it needs a runtime that this repository does not ship: the
loader answer alone gets the program started and leaves its paths pointing at the
phone. Treat it as a procedure with a missing ingredient.

**Prerequisites.** `adb`; a glibc userland packaged as a tarball, with its runtime
(loader shim and tracer) inside it and a `boot/boot.sh` entry point; about 300 MB
free on the phone.

**Time and size.** Push and extract: minutes. The tree used was about 265 MB.

**Steps.**

1. Push the tarball and extract it as the shell user:

   ```sh
   adb push tree.tar.gz /data/local/tmp/
   adb shell 'cd /data/local/tmp && mkdir -p tree && tar xzf tree.tar.gz -C tree'
   ```

2. Check the tree was built for this host, and restore what the extraction lost:

   ```sh
   adb shell 'cat /data/local/tmp/tree/boot/version'
   adb shell 'cd /data/local/tmp/tree && ./boot/boot.sh'
   ```

3. Confirm the identity and the package manager:

   ```sh
   adb shell 'cd /data/local/tmp/tree && ./boot/boot.sh -c "id; apt-get update | tail -n 2"'
   ```

**Expected.**

```
host=adb
uid=0(root) gid=0(root)
Get:1 http://deb.debian.org/debian trixie InRelease ...
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `No such file or directory` for every program | the runtime is not in the tree, or its loader path is not there | `ls tree/usr/lib/*/ld-linux*` |
| `sudo: must be setuid root` | extraction dropped the setuid bits | the tree's recorded setuid list, restored by the entry point |
| the tree dies when the cable is unplugged | the adb-started process does not outlive `adbd` | run it from an app-domain host, or re-attach from the PC |

**Undo.** `adb shell 'rm -rf /data/local/tmp/tree'`

**Cost.** The tree is in `/data/local/tmp`: it survives a reboot, not a factory reset,
and it does not outlive an `adbd` restart ([durability](../tree/durability.md)). The
runtime is a layer between the program and Android — isolation 2 or 3, not 0
([the isolation scale](../README.md#the-isolation-scale)).
