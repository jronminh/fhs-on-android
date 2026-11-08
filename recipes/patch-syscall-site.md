# Change what a syscall site asks for

**Goal.** A program calls a syscall directly, past libc. Rewrite that instruction —
on disk, or only in memory at load — so the call asks for something else. This is
the technique that lets a foreign binary reach a tree without a tracer.
**Isolation 1** on disk, **2** at load.

**Tested on.** Built on Debian 13 (WSL 2), ran in a Debian `arm64` chroot on a
Galaxy S21 FE, Android 15, kernel 5.4.242, 2026-11-08 [m].

**Prerequisites.** `gcc-aarch64-linux-gnu`, a running chroot tree
([debian-chroot-full](debian-chroot-full.md)), `objdump` for the same
architecture, Python 3 for the byte edit.

**Time and size.** A few minutes. The program is 70 KB; the patcher DSO is 68 KB.

**Steps.**

1. Write a program whose syscall is **not** behind a libc symbol:

   ```c
   #include <unistd.h>
   int main(void) {
       const char msg[] = "raw write via svc\n";
       register long x0 asm("x0") = 1;
       register long x1 asm("x1") = (long)msg;
       register long x2 asm("x2") = sizeof msg - 1;
       register long x8 asm("x8") = 64;   /* __NR_write */
       asm volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x8) : "memory");
       return 0;
   }
   ```

2. Build it and find the site:

   ```sh
   aarch64-linux-gnu-gcc -O0 -o raw raw.c
   aarch64-linux-gnu-objdump -d raw | grep -B3 'svc'
   ```

   ```
    794:	d2800808 	mov	x8, #0x40                  	// #64
    798:	d4000001 	svc	#0x0
   ```

3. **On disk**: patch the immediate, only if the pattern is unique:

   ```python
   b = open('raw', 'rb').read()
   old = bytes.fromhex('080880d2')   # mov x8, #64  (write)
   new = bytes.fromhex('881580d2')   # mov x8, #172 (getpid)
   assert b.count(old) == 1
   open('raw-patched', 'wb').write(b.replace(old, new))
   ```

4. Run both in the tree:

   ```sh
   chroot "$T" /usr/bin/env -i PATH=/usr/bin:/bin /root/raw
   chroot "$T" /usr/bin/env -i PATH=/usr/bin:/bin /root/raw-patched
   ```

5. **At load**: a constructor that finds the executable's text, makes it writable,
   patches the same four bytes, and leaves the file alone:

   ```c
   #define _GNU_SOURCE
   #include <dlfcn.h>
   #include <link.h>
   #include <string.h>
   #include <stdint.h>
   #include <sys/mman.h>
   #include <unistd.h>

   static const unsigned char OLD[4] = {0x08, 0x08, 0x80, 0xd2};
   static const unsigned char NEW[4] = {0x88, 0x15, 0x80, 0xd2};
   static int patch_main(struct dl_phdr_info *info, size_t size, void *data) {
       if (info->dlpi_name && info->dlpi_name[0]) return 0;      /* the main object */
       long pg = sysconf(_SC_PAGESIZE);
       for (int i = 0; i < info->dlpi_phnum; i++) {
           const ElfW(Phdr) *p = &info->dlpi_phdr[i];
           if (p->p_type != PT_LOAD || !(p->p_flags & PF_X)) continue;
           unsigned char *base = (unsigned char *)info->dlpi_addr + p->p_vaddr;
           uintptr_t start = (uintptr_t)base & ~(uintptr_t)(pg - 1);
           size_t len = p->p_memsz;
           size_t mlen = ((uintptr_t)base + len - start + pg - 1) & ~(size_t)(pg - 1);
           if (mprotect((void *)start, mlen, PROT_READ|PROT_WRITE|PROT_EXEC)) continue;
           for (size_t j = 0; j + 4 <= len; j++)
               if (!memcmp(base + j, OLD, 4)) { memcpy(base + j, NEW, 4); return 1; }
       }
       return 0;
   }
   __attribute__((constructor)) static void init(void) { dl_iterate_phdr(patch_main, 0); }
   ```

   ```sh
   aarch64-linux-gnu-gcc -shared -fPIC -O2 -o patchso.so patchso.c -ldl
   sha256sum raw
   LD_PRELOAD=/root/patchso.so /root/raw
   sha256sum raw
   ```

**Expected.**

```
raw write via svc
                       # nothing from the patched copy
cb58c835cc05533c4c8dac7d691111032e147e6e420f60d2ecf6d9c582456e0f  raw
                       # nothing, now with LD_PRELOAD
cb58c835cc05533c4c8dac7d691111032e147e6e420f60d2ecf6d9c582456e0f  raw
```

The call did not print: it asked the kernel for the pid, not for a write. The file
hash is the proof that the second run patched only memory.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `assert b.count(old) == 1` fails | the pattern is not unique, or the compiler folded it | `-O0`, or patch at a known offset from the disassembly |
| the patched program prints garbage | the new syscall expects different arguments | change the number **and** the setup, or patch to a compatible call |
| `mprotect` fails in the constructor | the segment is not writable and the platform refuses | `p_flags & PF_X` check, and the page rounding |
| `LD_PRELOAD` has no effect | the program is static, or it is setuid | the technique needs a dynamic, unprivileged program |

**Undo.** `rm -f /root/raw /root/raw-patched /root/patchso.so`

**Cost.** A pattern scan is a guess: the same four bytes may occur twice, and the
next compiler release may change the encoding. The version this technique comes
from found the site once, at build time, for one libc, and kept the offset. It is
a last resort behind [patching a package](../methods/patch-package.md) and ahead of
[a tracer](../methods/tracer.md).
