# Point a binary at another loader

**Goal.** Rewrite the one ELF field that decides which loader the kernel opens, and
see what that does and does not change. **Isolation 1.**

**Tested on.** Debian 13 (WSL 2), x86-64, 2026-11-08 [m]. A host run; on a phone
the same commands need `patchelf` on the host and the phone's own loader.

**Prerequisites.** `patchelf`, `readelf`, one dynamic binary, its loader file,
about 1 MB.

**Time and size.** A minute.

**Steps.**

1. Copy the binary and the loader into a directory:

   ```sh
   R=/tmp/patch-demo; mkdir -p "$R/bin" "$R/lib"
   cp /bin/true "$R/bin/true"
   cp /lib64/ld-linux-x86-64.so.2 "$R/lib/"
   ```

2. Rewrite the interpreter and read it back:

   ```sh
   patchelf --set-interpreter "$R/lib/ld-linux-x86-64.so.2" "$R/bin/true"
   readelf -l "$R/bin/true" | sed -n 's/.*program interpreter: \(.*\)]/\1/p'
   ```

3. Run it, then ask which libraries it actually got:

   ```sh
   "$R/bin/true" && echo "rc=0"
   ldd "$R/bin/true"
   ```

**Expected.**

```
/tmp/patch-demo/lib/ld-linux-x86-64.so.2
rc=0
	linux-vdso.so.1 (0x000070b341230000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x000070b34101e000)
	/tmp/patch-demo/lib/ld-linux-x86-64.so.2 => /lib64/ld-linux-x86-64.so.2 (0x000070b341214000)
```

The second half is the lesson: the **entry point** moved to the copied loader, the
**libraries** did not — `libc` is still the host's. A patched interpreter relocates
the start, not the tree.

**Two readers of one field** [s]. At `execve`, the kernel reads the interpreter
path **from the file**, through `PT_INTERP`'s `p_offset` and `p_filesz`, and never
maps it; it requires the last byte of the range to be NUL and opens up to the
first NUL. The loader, by contrast, names **itself** from memory: it takes
`p_vaddr` and adds the load address. A path longer than the old one therefore has
to move to a place with room, and `p_vaddr` has to follow it: moving only
`p_offset` starts the binary and breaks the loader's own name.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `No such file or directory` when running | the new interpreter path does not exist | `ls -l` the path inside the binary |
| `Text file busy` | the binary is executing | patch a copy, or a file not in use |
| `Exec format error` | the loader is for another architecture | `readelf -h` both files |

**Undo.** `rm -rf /tmp/patch-demo`.

**Cost.** The path is baked: move the directory and the binary stops starting. The
library search is unchanged, so a tree still needs its own cache or a loader that
derives its prefix ([loader](../methods/loader.md)).
