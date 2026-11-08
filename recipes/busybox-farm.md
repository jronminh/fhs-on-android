# One busybox, a farm of applet links

**Goal.** Give the tree one implementation of the tools it uses, with the same
options on every phone, instead of whichever applet the ROM happens to ship.
**Isolation 0.**

**Tested on.** Three phones, 2026-11-08 [m]: Sharp 701SH, Android 10 (sdk 29);
Galaxy S10e, Android 12 (sdk 31); Galaxy S21 FE, Android 15 (sdk 35). The **same
binary** was pushed to all three: busybox **1.36.1.1**, **358 applets**, 1.7 MB.

**Prerequisites.** `adb`, no root; one static busybox (`readelf -l BUSYBOX | grep -c
interpreter` prints 0); about 2 MB.

**Time and size.** A second. The farm is **1.68–1.77 MB** depending on the filesystem.

**Steps.**

1. Put the binary and an empty shims directory in the tree:

   ```sh
   T=/data/local/tmp/farm
   mkdir -p "$T/bin/shims"
   adb push busybox "$T/bin/busybox"
   chmod 755 "$T/bin/busybox"
   ```

2. Create **relative** links for the tools you want:

   ```sh
   for a in awk base64 cat cut date df find grep mktemp sed sha256sum \
            timeout top ip tr xargs gzip; do
       ln -sfn ../busybox "$T/bin/shims/$a"
   done
   ```

3. Put the shims first on `PATH` and test:

   ```sh
   export PATH="$T/bin/shims:/system/bin"
   "$T/bin/busybox" | head -n 1
   echo hello | sed s/hello/ok/
   echo 1 2 | awk '{print $1+$2}'
   ```

**Expected.**

```
BusyBox v1.36.1.1 topjohnwu (2024-10-06 01:38:43 PDT) multi-call binary.
ok
3
```

All twenty names resolved on all three phones, and every one of them was also in
`busybox --list`.

**What the measurement changed.** All twenty tools also existed on `/system/bin` on
all three phones, including `ip`, which is **iproute2** (`ip utility,
iproute2-ss171113`), not toybox. On these devices the farm is therefore not about a
missing tool: it is about **one implementation with the same options** on a phone
whose ROM you do not control. Keep the list short and deliberate.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `tool: inaccessible or not found` | the link resolves to a path that does not exist | `ls -l` the link; it must point at `../busybox` |
| the system tool runs instead of the farm's | `bin/shims` is not first on `PATH` | `command -v sed` must name the farm |
| busybox itself will not run | it is dynamic, not static | the `readelf` check above |
| an applet is missing | that busybox was built without it | `busybox --list | grep -x` the name |

**Undo.** `rm -rf /data/local/tmp/farm`

**Cost.** 1.7 MB per tree, and GPL-2.0: the binary is shipped by the operator, not
by a repository. A tool used from the system instead is a tool whose behaviour
depends on the phone ([the host's own material](../tree/bionic.md)).
