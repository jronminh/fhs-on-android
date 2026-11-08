# The loader

Isolation **0-2**, depending on which of the three you use. This is the surface a
dynamic glibc program cannot avoid: the kernel opens the interpreter named in
`PT_INTERP` before `main`, and the loader then opens the libraries, the cache and
the program's own files. Under a tracer that startup floor is **4-9 stops**, and
it grows with the number of linked libraries [m].

## What it buys

- **The least expensive unmodified path** (level 0): no layer sits between the program
  and Android's kernel; the tree supplies the loader and the cache, nothing else.
- **Multi-distro scope**: a Debian, an Ubuntu and an Arch tree boot with the same
  core, because the loader comes from the program, not from a constant [m].
- **A fast path** (level 2): a shim answers most calls with no stop - `git` 33 to 9
  stops, `python3` 108 to 15, `dpkg` 91 to 83 [m].

## What it costs

- **A startup floor nothing can answer**: the loader's own reads happen before any
  constructor of yours runs.
- **Blind spots** for the shim: static binaries, raw syscall(), anything libc does
  before or around it.
- **The ABI floor**: a shim built against a newer glibc than the tree carries fails
  to load, so record which libc it was built against.
- **A fragile patch**: the in-loader syscall patch is the part that breaks, so keep
  a way to boot with it off.

## The three techniques

| technique | level | how |
| --- | --- | --- |
| **the loader the tree names** | 0 | take `PT_INTERP` from the program, resolve it in the tree, and let the tree's `ld.so.cache` find the libraries |
| **a preloaded shim** | 2 | `LD_PRELOAD` redefines the path-taking symbols, and patches libc's own syscall sites in place |
| **an interpreter instead of the loader** | 2 | point `PT_INTERP` at a real ELF that sets up the environment and `exec`s the real loader; replaced by the in-loader patch |

## Example

[examples/shim-open.c](../examples/shim-open.c) is the idea of a path shim in one
symbol, and its header comment names what it cannot reach:

```c
static const char *map(const char *p, char *buf)
{
    if (!p || p[0] != '/' || !tree()[0]) return p;
    snprintf(buf, PATH_MAX, "%s%s", tree(), p);
    return buf;
}
/* Not reached, by construction: a static binary, a raw syscall(), and the reads
 * libc performs inside itself (NSS, gconv, ld.so.cache). */
```

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `No such file or directory` running an existing file | the kernel resolved `PT_INTERP` against the real root | readelf -l, then patch the package or take the loader from the program |
| `error while loading shared libraries: libfoo.so.1` | `DT_NEEDED` resolved through the real root's cache | the tree's own ldconfig / ld.so.cache |
| `version 'GLIBC_2.38' not found` on a shim | the ABI floor was crossed | rebuild the shim against the tree's libc |
| a program reads the phone's `/etc` with the shim on | it is static, or it calls syscall() directly | it falls to the tracer, by design |

## By domain

The loader runs the same in all three domains. In **app**, Gate A applies to the
program's own syscalls and a trapped call is a signal, not an `errno`
([reference/domains.md](../reference/domains.md)); the shim changes nothing about
that.

## Evidence

The startup floor and the shim's stop counts are measured on a reference device
[m, 2026-10]; an Ubuntu prefix of 174 MB booted with the tree's loader and cache
[m, 2026-10-17]; the interpreter technique was built and then replaced by the
in-loader patch [s].

## Tried, not kept - and what it cost

- **Patching libc's cancellable path** (`__syscall_cancel_arch`): a second patch site to
  keep in step with every glibc change, and a mistake there stays invisible until
  a thread takes that path.
- **A fused loader** - the loader merged into the tree at build time. Described as
  the method behind a build-time package translation; the branch is not in this
  checkout, so the claim stands unverified here [u].
