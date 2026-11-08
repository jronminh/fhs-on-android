# A compiler in the tree that links with the tree's loader

**Goal.** `gcc -o prog prog.c` *inside* the tree produces a binary that runs
there, without `-Wl,--dynamic-linker` on every command. **Isolation 1.**

**Basis.** **Recorded** — the project's gcc-specs fix `dn-fix-gcc-specs.sh`, in
deb-native's history (the finding behind it: 2026-10-01, "the shim's `/lib` gap,
and a separate `PT_INTERP` wall"). Not re-run here: the phones have no compiler
[m] and no tree on them carries one. The wall it fixes is [s].

**Prerequisites.**

- a tree with a glibc **and a gcc** installed in it;
- the tree's loader at `usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1`;
- `gcc`'s own `libgcc.a` directory, where it looks for `specs`.

**Time and size.** A second per gcc version. One small file.

**Steps.**

1. Find the loader and check the tree has a gcc:

   ```sh
   LD="$T/usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1"
   [ -x "$LD" ] && [ -d "$T/usr/lib/gcc" ] || exit 0
   ```

2. Write a `specs` file beside each `libgcc.a`, with only gcc's dynamic-linker
   literal replaced — everything else stays gcc's own defaults:

   ```sh
   OLD='/lib/ld-linux-aarch64%{mbig-endian:_be}%{mabi=ilp32:_ilp32}.so.1'
   for d in "$T"/usr/lib/gcc/*/*; do
       [ -d "$d" ] || continue
       "$T/usr/bin/$(basename "$(dirname "$d")")-gcc-$(basename "$d")" -dumpspecs \
           | sed "s#$OLD#$LD#" > "$d/specs"
   done
   ```

3. Idempotence: skip a version whose `specs` already names the loader, and skip
   the whole step when gcc is not installed yet — a no-op, not an error.

4. Test it from inside the entry
   ([an entry script](entry-script.md)):

   ```sh
   gcc -o /tmp/hello hello.c && /tmp/hello && echo "runs"
   readelf -l /tmp/hello | sed -n 's/.*interpreter: \(.*\)\]/\1/p'
   ```

**Expected.** `readelf` prints the tree's loader path, and the binary runs. The
package install that brought gcc in can then build for the tree with no extra
flags.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| the binary still names `/lib/ld-linux-aarch64.so.1` | the `specs` file is not where gcc looks for it | `gcc -print-libgcc-file-name`, and put `specs` beside it |
| the `specs` file exists and nothing changed | gcc's own literal differs from `$OLD` (a newer gcc) | `gcc -dumpspecs \| grep dynamic-linker`, and adjust the pattern |
| `gcc: not found` | a cross compiler in the tree, not a native one | use the `aarch64-linux-gnu-gcc` name, and the cross toolchain's `libgcc.a` |
| `version 'GLIBC_2.38' not found` at run | the program was built against a newer libc than the tree's | not a specs problem: build it against the tree's libc |

**Undo.** Remove the `specs` files; gcc falls back to its built-in default.

**Cost.** The `specs` is tied to a gcc version and to the tree's loader path; a
gcc upgrade may replace or ignore it. It is the smallest possible edit for the
problem — one string in a file gcc already reads — and it needs no rebuild of
gcc or binutils.
