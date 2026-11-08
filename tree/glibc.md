# Supply: a glibc userland

A userland the phone does not have: Debian `arm64`, Ubuntu, Arch — a root
filesystem imported and made to run. It buys unmodified software, `apt`,
compilers, `git`; it costs the whole emulation of `/`
([methods/](../methods/README.md)), and it cannot reach isolation level 0. If you
do not need the package manager, [the host's own material](bionic.md) is cheaper.

## What the import has to get right

1. **The loader must be findable.** A dynamic ELF names its loader in `PT_INTERP`
   and the kernel resolves it against the real root. Nothing else in the file
   decides whether the program starts ([methods/patch-package.md](../methods/patch-package.md)).
2. **The ordering constraint.** The layer that answers paths and identity must
   exist **before the first package is installed**, because a package's `preinst`
   runs binaries that already assume the world. The reference pipeline runs
   `debootstrap --second-stage` *under* the runtime, so maintainer scripts run as
   they would on Debian: that step, not the download, is the test of a runtime.
3. **The tree must not bake its own path.** The entry point derives the tree from
   its own location; an unprivileged `tar` drops setuid bits, so the build records
   them and the boot restores them.

A distribution's libc need not be forked to get the tree's paths: the smallest
import keeps the distribution's `libc6` and `libc-bin` whole and replaces the
**ten files** a patch changes ([patched libc](../methods/patched-libc.md)).

## It runs under chroot

A minimal glibc tree — `dash`, `libc.so.6`, `ld-linux-aarch64.so.1` — is **2.1 MB**
and runs under `chroot` with no shim and no tracer [m, 2026-11-08]: the loader
reports `Debian GLIBC 2.41` from inside, and `dash` executes with the tree's libc.
The loader must be `0755`: an `adb push` gives 0644, and the kernel answers
`Permission denied` rather than anything that names the loader
([chroot](../methods/chroot.md#the-two-loader-states-that-come-first)).

## What it must pass

A glibc tree is not built until four checks pass, and each one fails in a different
layer:

| check | what it proves | where it fails |
| --- | --- | --- |
| `id` says `uid=0(root)` | the identity layer answers | [identity](../methods/identity.md) |
| `apt-get update && apt-get install figlet` | maintainer scripts run; the relocation is healthy | [patch](../methods/patch-package.md), then [limits](../reference/limits.md) |
| `git init /tmp/x && git status` | paths and the loader agree | [loader](../methods/loader.md) |
| `python3 -c 'import os; list(os.walk("/usr"))'` | the syscall surface is wide enough for real work | [tracer](../methods/tracer.md) |

## What it measures

Built on the reference device (S10e, Android 12): about three minutes, 265 MB for
the minimal set, 811 MB with a toolchain — most of it download [m]. The Ubuntu
case is the multi-distro proof: a `noble` minimal prefix of 174 MB, booting with
the tree's own loader and `ld.so.cache`, `apt-get update` verifying against the
tree's keyring, `apt-get install hello` running [m, 2026-10-17].

## Three failures in five minutes

Three failures show why a layer exists: a **static** binary runs at
once and then reads the *phone's* root; a **dynamic** one dies before `main` with
`No such file or directory` although the file is there — the kernel resolved
`PT_INTERP` against the real root and found no loader; and rewriting the interpreter
fixes the entry point and nothing else, while **baking** the path so the tree can
no longer move.

## When it breaks

In order: the last failure in `debootstrap.log`; the shim turned off; the
userland exec turned off; then [the failure catalogue](../reference/limits.md).
