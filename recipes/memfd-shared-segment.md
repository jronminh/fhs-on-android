# A shared segment without SysV IPC

**Goal.** Two processes share memory when the kernel has no SysV IPC and no
`/dev/shm`. **Isolation 0.**

**Tested on.** Three phones, 2026-11-08 [m]: Android 10 (sdk 29), 12 (sdk 31), 15
(sdk 35). On all three: `shmget` returns **Function not implemented**,
`/dev/shm` does not exist, and `memfd_create` works.

**Prerequisites.** A compiler, or a tree with one; a static binary is enough, and
no root is needed.

**Time and size.** A minute. The static binary is 780 KB.

**Steps.**

1. Create a `memfd`, size it, map it shared, and fork:

   ```c
   #define _GNU_SOURCE
   #include <stdio.h>
   #include <string.h>
   #include <unistd.h>
   #include <sys/mman.h>
   #include <sys/wait.h>

   int main(void) {
       int fd = memfd_create("seg", 0);
       if (fd < 0 || ftruncate(fd, 4096) != 0) { perror("memfd"); return 1; }
       char *p = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
       if (p == MAP_FAILED) { perror("mmap"); return 1; }
       strcpy(p, "written by the parent");
       if (fork() == 0) { strcpy(p, "written by the child"); _exit(0); }
       wait(NULL);
       printf("segment: %s\n", p);
       return 0;
   }
   ```

2. Build it static, push it, run it:

   ```sh
   aarch64-linux-gnu-gcc -static -O1 -o memfd memfd.c
   adb push memfd /data/local/tmp/memfd
   adb shell 'chmod 755 /data/local/tmp/memfd && /data/local/tmp/memfd'
   ```

**Expected.**

```
segment: written by the child
```

The parent reads what the child wrote: one file descriptor, one mapping, no
segment id and no `ipcs`.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `shmget: Function not implemented` | this kernel has no SysV IPC | expected on all three phones; use `memfd` |
| `shm_open: No such file or directory` | `/dev/shm` is absent | checked: absent on all three |
| the child's write is invisible | the mapping was `MAP_PRIVATE`, or the fd was reopened | `MAP_SHARED`, and pass the fd, do not reopen |
| an unrelated process cannot see it | `memfd` has no name to open | pass the fd over a socket with `SCM_RIGHTS` |

**Undo.** `adb shell 'rm -f /data/local/tmp/memfd'`

**Cost.** This helps code you write; a foreign program that calls `shmget` still
fails, and making it work needs a broker that answers the call
([a tracer](../methods/tracer.md)). The kernel's refusal is not a bug to patch
around in the program.
