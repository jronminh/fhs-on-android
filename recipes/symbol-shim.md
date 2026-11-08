# Prefix absolute paths with a preloaded DSO

**Goal.** Make a dynamic program open files under a tree without touching the
binary or the tree. **Isolation 2.**

**Tested on.** Debian 13 (WSL 2), x86-64, 2026-11-08 [m].

**Prerequisites.** `gcc`, a dynamic program to test with, about 1 MB.

**Time and size.** Two minutes.

**Steps.**

1. Build the shim from [examples/shim-open.c](../examples/shim-open.c):

   ```sh
   gcc -shared -fPIC -O2 -o /tmp/shim.so ../examples/shim-open.c -ldl
   ```

2. Make a tree with one file to be found:

   ```sh
   mkdir -p /tmp/tree/etc && printf 'from-the-tree\n' > /tmp/tree/etc/hostname
   ```

3. Compare the same call with and without the shim:

   ```sh
   cat /etc/hostname
   TREE=/tmp/tree LD_PRELOAD=/tmp/shim.so cat /etc/hostname
   ```

**Expected.**

```
DESKTOP-BLO8L2L
from-the-tree
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| the tree's file is not used | the program is static, or it calls `syscall()` | `ldd` the program; a static one needs [rebuild](../methods/rebuild.md) |
| the program crashes at start | the DSO was built for another architecture or libc | build it on the target, or with the target's compiler |
| some paths map and others do not | the symbol the program calls is not in the shim | `nm -D` the shim against the program's imports |

**Undo.** `rm -rf /tmp/tree /tmp/shim.so`.

**Cost.** Blind spots, by construction: a static binary sees the host, and so does
anything libc reads inside itself before the symbol is reached
([loader](../methods/loader.md)).
