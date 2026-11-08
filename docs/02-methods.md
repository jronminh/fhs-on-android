# 2. The methods

There are many ways to run an FHS tree on Android and they differ along three
independent axes. Most confusion in this area comes from mixing the axes, so
they are separated here first, then combined into concrete methods.

1. **Who resolves the paths?** the kernel, a tracer, a preloaded library, or a
   rewritten file.
2. **Who answers the kernel refusals?** nobody (fail honestly), a supervisor that
   traps the signal, or a shim that never issues the call.
3. **Who produces the identity?** the kernel (real uid), a shim, or a tracer.

Nothing forces one answer per axis, and the good designs mix them per syscall
class. That is the whole of the design space; everything below is a point in it.

## M0 — Do not translate: build natively

Compile with the NDK (bionic) and run from `/data/local/tmp` or the app's lib
directory. No paths, no gate problems, no loader.

- **Buys** native speed and zero moving parts.
- **Costs** no FHS, no `apt`, no `dpkg`; every program has to be ported or
  rebuilt.
- **Pick it** when you control the source of everything you want to run.

## M1 — root: `chroot` and bind mounts

On a rooted phone the problem disappears: `chroot` to the tree, bind-mount
`/proc`, `/sys`, `/dev`, and the tree is a real root filesystem.

- **Buys** everything: real uid 0, real mounts, native speed, `apt` works
  unmodified, setuid works.
- **Costs** a rooted device, `busybox` on the host, a boot-time script, and the
  security model of the phone is now yours to keep.
- **Pick it** when the phone is a lab device and you own the root story.

## M2 — proot: translate at the syscall boundary, no root

`proot` runs the tree under `ptrace` and rewrites path arguments (and some
identity answers) on every syscall. It needs no privilege, which is why
`proot-distro` on Termux is the standard "Linux on Android" answer.

- **Buys** a complete, relocatable FHS tree with no root and no per-file edits.
  It catches `execve`, static binaries, raw syscalls — everything, because it
  sits at the boundary where nothing can escape.
- **Costs** a `ptrace` stop per traced syscall. Metadata-heavy work (`find`,
  `apt`, `git status`, a large `configure`) pays the most; CPU-bound work pays
  almost nothing. Expect a large factor on the first kind and close to 1× on the
  second — measure yours, do not trust a number from someone else's phone
  ([06](06-measure.md)).
- **Misses** nothing at the syscall level; it is the method with the fewest
  coverage holes and the highest steady cost.

## M3 — user namespaces

`unshare(CLONE_NEWUSER|CLONE_NEWNS)` + `chroot` inside the namespace gives a real
mount namespace and "root" that is only root inside it.

- **Buys** the M1 model without root, at native speed.
- **Costs** everything if the kernel forbids it. Android kernels commonly compile
  user namespaces out or restrict them for unprivileged callers, and SELinux has
  to allow it. Check with the probe before designing around it: this is the
  method most often reported to work and most often not available.
- **Pick it** only after `unshare -Ur` succeeds on the target device.

## M4 — `LD_PRELOAD` symbol interposition only

A preloaded DSO redefines the path-taking libc symbols (`open`, `openat`,
`stat`, `access`, `execve`, `dlopen`, ...) and prefixes absolute paths with the
tree.

- **Buys** near-native speed, no privilege, no per-file edits, no tracer.
- **Costs** blind spots that are structural, not bugs: static binaries, programs
  that call `syscall()` directly, syscalls made inside libc itself (NSS, `gconv`,
  `ld.so.cache`), and the loader's own reads before any preload exists.
- **Pick it** never alone, if the goal is a tree that passes bars 2 and 3
  ([README](../README.md#three-bars-for-it-works)). It is a fast path, not a
  method.

## M5 — hybrid: rewrite, interpose, trace

The method this guide's measurements come from. Four mechanisms, each used where
it is cheapest, with **one** implementation of the path rule:

| mechanism | where it acts | covers |
| --- | --- | --- |
| **static rewrite** — `PT_INTERP`, shebangs, launchers | at install or build time | assumption 2 and 6, cheaply, forever |
| **loader shim** — a preloaded DSO | in-process, at the symbol | the reads and writes libc performs on the program's behalf |
| **tracer** — `ptrace` + a seccomp filter | at the syscall boundary | static binaries, raw syscalls, libc-internal reads, identity |
| **userland exec** — map the loader yourself | at `execve` | relocation and high-`targetSdk` domains where the kernel refuses to `execve` app data |

- **Buys** near-native speed (the shim answers most calls with no stop) plus the
  tracer's coverage, with no privilege and no per-syscall cost on the hot path.
- **Costs** three components to build and keep in agreement, and a rule that has
  to be written once and shared. The failure mode of this method is **two
  implementations of the path rule disagreeing** — the 0.7 generation of the
  reference implementation died of exactly that, and every design review since
  has been about collapsing copies of the rule into one owner.
- **Pick it** when bars 2 and 3 matter: `apt` unmodified, a compiler, `git`.

## M6 — a foreign-libc bundle (`glibc-runner`, `termux-packages` glibc)

Ship a glibc and a patched loader as a package for the *existing* Termux prefix,
then run individual binaries against it.

- **Buys** the fastest route to running one glibc program on a phone: install a
  package, run the command. No tree, no tracer, no root.
- **Costs** it is not a system: no `dpkg`, no FHS, no dependency resolution,
  no `apt`. Programs that expect `/usr/share` or a package database do not work.
- **Pick it** when you want a *binary*, not a *tree*. Confusing M6 with M5 is the
  most common category error in this space.

## M7 — userland exec

Instead of letting the kernel `execve` the program, `mmap` the loader (or the
static program) yourself, patch its syscall sites, and jump.

- **Buys** the only path that works when the platform forbids `execve` of files
  in app data (apps targeting API 29+ on modern Android), and it makes syscall
  patching possible in memory that the process owns — no `execmod` needed.
- **Costs** you now implement the ELF loading contract: auxv, stack layout,
  `AT_EXECFN`, `PT_INTERP`, and the loader's own expectations. Get one field
  wrong and the failure is a segfault with no message.
- **Pick it** when you are the host app on a modern `targetSdk`, or when you need
  a fast path for static binaries.

## M8 — CPU emulation (a different axis)

`box64`, FEX, `qemu-user`, iSH. This is about *running another architecture*, not
about paths, and it composes with any method above: an x86 tree inside an arm64
prefix under `box64` is M5 + M8.

Not covered further here except in [07](07-prior-art.md), because it changes the
performance model without changing the platform model.

## Combining them: what a complete method needs

A method that reaches bar 3 needs, at minimum, one answer per row. Leaving a row
empty is a known hole, not a TODO:

| need | cheapest answer | complete answer |
| --- | --- | --- |
| a loader that finds the tree | `patchelf` the `PT_INTERP` to an absolute path | a loader that derives its prefix from its own location, so the tree is relocatable |
| shebangs | rewrite `#!` to the real path of the tree's interpreter | a generic real-ELF interpreter that sets up the environment and `exec`s the real one |
| libc-internal reads (NSS, `gconv`, cache) | a prefix-owned `ld.so.cache` and `nsswitch` + the shim | the shim, plus the tracer for what bypasses it |
| static binaries, raw syscalls | nothing | the tracer |
| Gate A (`SIGSYS`) | nothing — the process dies | a handler installed from the first instruction, or a supervisor attached to it |
| identity (`uid 0`, `chown`, setuid) | shim-level fake answers | shim + tracer for the static/raw cases, with an escape hatch to the real identity |
| path rule | one function, one owner | the same, and **never** a second copy in another component |
| service supervision | run services from the host app | a userspace supervisor (`runit`) inside the tree, since there is no PID 1 to give it |
| `execve` on modern Android | — | userland exec (M7) |

## Decision tree

```
Do you have root?
├── yes ─────────────────────────────► M1 (chroot + binds). Stop reading.
└── no
    Does `unshare -Ur` succeed on the device?   (probe it, do not assume)
    ├── yes ────────────────────────► M3 (userns + chroot). Native speed, real mounts.
    └── no
        Do you need a *tree* (apt, dpkg, a compiler) or just a *binary*?
        ├── just a binary ──────────► M6 (glibc bundle). Ten minutes, done.
        └── a tree
            Is a 2–10× slowdown on metadata-heavy work acceptable?
            ├── yes ────────────────► M2 (proot). Most robust, least work.
            └── no ─────────────────► M5 (hybrid) + M7 where the platform
                                      forbids execve. Read 03, then 05.
```

## Two rules that survive every method

1. **One owner per rule.** If two components each decide what `/etc/passwd`
   means, they will eventually disagree, and the bug will look like a random
   `ENOENT` in one path and not another. Collapse the rule to one
   implementation and make the others clients of it.
2. **A fast path is not the method.** A shim is an optimisation that skips a
   cost; the moment it is the *only* answer for a syscall class, correctness now
   depends on which binaries happen to be dynamic. Always keep the full-coverage
   layer underneath, and be explicit about which programs fall to it.
