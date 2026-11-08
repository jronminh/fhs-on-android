# Building the tree's glibc from source

Debian's `.deb` is the measured supply of a glibc userland
([the glibc tree](../tree/glibc.md)); a tree that must name no distribution, or
be smaller or newer than Debian's packages allow, is built from source instead.
None of the routes below builds a **kernel**: the phone's kernel is the host's,
so the half of these books that builds one does not apply.

## LFS: the shape that matters

[Linux From Scratch](https://www.linuxfromscratch.org/lfs/) builds a Linux
system from source. Its three structural ideas are what a source tree needs [s]:

- **The toolchain bootstrap.** Build `binutils`, then a bootstrap `gcc` and
  `glibc` into a scratch prefix (LFS uses `/tools`), enter it, build the *real*
  toolchain there, then rebuild the temporary tools with it. One throwaway
  toolchain breaks the chicken-and-egg, and it is the recipe to take when a tree
  carries its *own* glibc instead of Debian's — which is also how the
  `Debian GLIBC 2.41` fingerprint stops appearing in every binary.
- **Build in a scratch area, then produce the image.** The same split this guide
  uses everywhere: the builder and the tree are two things.
- **Size from the package list.** Under 500 MB by the book, smaller for one
  purpose (the book's Apache-only system is under 200 MB).

## The recursion

LFS needs a working Linux host with a toolchain. A tree can *be* that host: a
Debian tree on the phone (level 1–3, [the methods](../methods/README.md)) runs
the book, and its output is a second tree — a Linux built from source, native on
Android, naming no distribution [u]. So the order can be: import Debian, use it
as the builder, and keep the result.

## The neighbours

| reference | what it is | what to take |
| --- | --- | --- |
| [BLFS](https://www.linuxfromscratch.org/blfs/) | the catalog past the LFS base: servers, X, libraries | the package selection, as data |
| ALFS and the hints | scripts that automate the book | the shape of a scripted builder |
| [Buildroot](https://buildroot.org/) | a `menuconfig` tree with a cross toolchain and thousands of packages, 15–30 minutes | "package selection as data", done well |
| mkroot and toybox | one script, a tiny root filesystem | how small a tree can be |

Buildroot and mkroot also build a kernel and a bootloader; that half is not this
guide's — the tree does not own the machine.

## What it costs

- **Several `gcc`/`glibc` passes**: hours, disk and heat. It is a one-time,
  offline builder step whose output is an image, not something done on the phone
  daily.
- **No package manager comes with it.** LFS is a guide, and the manager is the
  tree's choice: a fixed image (what the busybox bundle already is), a source
  manager (`kiss` is a few hundred lines of POSIX `sh`; `pkgsrc` is larger), or
  a binary manager (`dpkg`, `apk`).

## What it changes for the methods

- **The loader is the tree's own**, at a path no other tree knows. A program's
  `PT_INTERP` names it, so the tree runs at the
  [loader](../methods/loader.md)'s level 0–1 instead of being patched to a
  constant — and it moves without rewriting every `PT_INTERP` in it
  ([own libc](../methods/own-libc.md)).
- **No distribution fingerprint**: nothing in the tree announces Debian, which
  is what "names no distribution" means in practice.

## What this guide has not done

It has not built one. The route is described, not run: the guide's next step is
to build glibc from source on a Linux host (the LFS bootstrap) and run it under
`chroot` on the phone, recording what breaks [u]. A build *inside* a tree on the
phone is further off, because it needs a toolchain in the tree first.

## Evidence

- **[s]** the shape of LFS, BLFS, Buildroot and mkroot as their books and sites
  describe them; the builder/image split, which this guide already uses.
- **[u]** the recursion (a tree as the builder), and the run: not built here, and
  named as the next step.
