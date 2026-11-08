# Answer identity at the symbol layer

**Goal.** Report a different uid and a successful `chown` without privilege, and
see which checks still fail. **Isolation 2.**

**Tested on.** Debian 13 (WSL 2), x86-64, 2026-11-08 [m].

**Prerequisites.** `gcc`, about 1 MB.

**Time and size.** A minute.

**Steps.**

1. Build the shim from [examples/identity.c](../examples/identity.c):

   ```sh
   gcc -shared -fPIC -O2 -o /tmp/identity.so ../examples/identity.c
   ```

2. Ask who you are, with and without it:

   ```sh
   id -u
   LD_PRELOAD=/tmp/identity.so id -u
   ```

3. Try the check that verifies rather than asks:

   ```sh
   touch /tmp/owned
   LD_PRELOAD=/tmp/identity.so chown root /tmp/owned; echo "chown rc=$?"
   ls -ln /tmp/owned | awk '{print "owner on disk:", $3":"$4}'
   ```

**Expected.**

```
1000
0
chown: changing ownership of '/tmp/owned': Operation not permitted
chown rc=1
owner on disk: 1000:1000
```

The uid changes; the `chown` does not, because the program calls `fchownat`, which
the shim does not define. A symbol-level answer covers exactly the symbols the
program uses.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `id -u` still shows the real uid | the shell stripped `LD_PRELOAD` | run the program directly, not through a wrapper |
| the program crashes | the DSO's architecture or libc differs | build it on the target |
| `chown` succeeds | the process really is privileged | run it as a normal user |

**Undo.** `rm -f /tmp/identity.so /tmp/owned`.

**Cost.** Every answer must come from one owner, or the program can compare two of
them and see the disagreement ([identity](../methods/identity.md)).
