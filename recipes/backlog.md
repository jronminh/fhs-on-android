# Backlog

What is not a recipe yet, why, and what it would take. The index
([README](README.md)) lists what can be followed today; this page lists the rest,
so that a gap is a decision and not an omission.

## Ready, no runtime needed

| candidate | teaches | needs | cost |
| --- | --- | --- | --- |
| **netlink, and what leaks** | a tree that reads the phone's interfaces through netlink sees the *host's* truth; that is a documented leak, not a bug | a chroot tree | minutes |
| **a 32-bit userland in a 64-bit phone** | `debootstrap --arch=armhf`: a tree that runs armhf binaries while bionic is 64-bit | kernel 32-bit support; 60 s build | minutes |
| **the three lookups of `ld.so`** | search order without a cache: default dirs, `LD_LIBRARY_PATH`, `ld.so.cache`; and what `ldconfig` writes | a small glibc tree | minutes |
| **two roots, one terminal** | sibling userlands with no containment: `PATH` and a nested shell, `exit` returns; nothing isolates them | three phones | minutes |
| **`--force-architecture` is not `--add-architecture`** | dpkg's two mechanisms, and why a path still moves | a host with dpkg | a minute |
| **a maintainer script keeps a raw shebang** | `dpkg --configure` fails because the kernel runs the script without the shim; the fix is rewriting *every* shebang | a package-manager tree | minutes |
| **an alternatives link outside the prefix** | `update-alternatives` joins compiled-in absolute dirs, so the link lands in the host tree | a package-manager tree | minutes |

## Needs a runtime — sketch until one exists

| candidate | teaches | blocked on |
| --- | --- | --- |
| **a SysV IPC broker** | `shmget`/`semget`/`msgget` answered in user space, segments as `memfd` passed with `SCM_RIGHTS` | the runtime, and a named workload |
| **an in-process identity owner** | one owner answers `getuid`/`chown`/`setuid` at the boundary, so two answers cannot disagree | the runtime |
| **the overlay fast path** | paths resolve in one policy layer; static and foreign loaders fall back to a tracer with the same result | the runtime |
| **a host hook** | a script that runs with zero userlands, and a prefix service that runs with one | the app that calls it |

## Needs hours, or hardware

| candidate | teaches | blocked on |
| --- | --- | --- |
| **glibc built from source** | the LFS bootstrap, and a tree with no distribution fingerprint | hours on a host |
| **a virtual machine as the host** | isolation 5, AVF | a device that has it |
| **one host, three distributions** | the same core with Ubuntu, Debian and Arch trees | a repeat of the build per distro |

## The order this page recommends

1. the four that need only a tree: netlink, the 32-bit userland, `ld.so`, and the
   two-roots recipe;
2. the host-only page: dpkg's two mechanisms (the `PT_INTERP` invariants are
   already in [patch-interp](patch-interp.md));
3. the package-manager failures (shebang, alternatives) when a tree with `dpkg`
   is up;
4. everything under "needs a runtime" waits for one, and is not written as a
   recipe until it exists.
