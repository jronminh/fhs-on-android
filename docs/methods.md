# 3. The methods

There are many ways to run a tree on Android and they differ along three
independent axes. Most confusion in this area comes from mixing the axes, so
they are separated here first, then combined into concrete methods.

1. **Who resolves the paths?** the kernel, a tracer, a preloaded library, a
   rewritten file — or the program itself, taught at build time.
2. **Who answers the kernel refusals?** nobody (fail honestly), a supervisor that
   traps the signal, or a shim that never issues the call.
3. **Who produces the identity?** the kernel (real uid), a shim, or a tracer.

Nothing forces one answer per axis, and the good designs mix them per syscall
class. That is the whole of the design space; everything below is a point in it.

Which *kind* of tree you are building ([two kinds](two-kinds-of-tree.md)) decides
which of these are even on the table: M2–M7 exist to make foreign code run; M0,
M9 and M10 are what you use when the host's own material is enough.

## M0 — Do not translate: build natively

Compile with the NDK (bionic) and run from `/data/local/tmp` or the app's lib
directory. No paths, no gate problems, no loader.

- **Buys** native speed and zero moving parts.
- **Costs** no FHS, no `apt`, no `dpkg`; every program has to be ported or
  rebuilt.
- **Pick it** when you control the source of everything you want to run.

M0 has a second, larger form: instead of one binary, a whole **layout of
scripts** — a poor-host tree — that uses the host's shell, toybox and busybox and
adds nothing foreign at all ([a poor-host tree](poor-host-tree.md)). That is the
only tree that can live in a boot image ([root](root.md)).

## M1 — root: `chroot` and bind mounts

On a rooted phone the path problem disappears: `chroot` to the tree, bind-mount
`/proc`, `/sys`, `/dev`, and the tree is a real root filesystem.

- **Buys** everything: real uid 0, real mounts, native speed, `apt` works
  unmodified, setuid works.
- **Costs** a rooted device, and the phone's security model is now yours to keep.
- **Pick it** when the phone is a lab device and you own the root story.

Root buys more than `chroot`, and costs more than an unlock: what it grants, what
it takes, and — the part that decides whether your tree survives a reset — where
state may live, is [root](root.md).

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
  ([measurement](measure.md)).
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
  ([README](../README.md#four-bars)). It is a fast path, not a method.

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

Not covered further here except in [prior art](prior-art.md), because it changes the
performance model without changing the platform model.

## M9 — teach the program where the tree is

Do not translate at run time: build the program (or patch its source) so every
absolute path it *owns* points into the tree.

```c
/* before */  snprintf(home, sizeof home, "/root");
/* after  */  snprintf(home, sizeof home, "%s/home", s21_tree());
```

plus `PATH` beginning with `TREE/bin`, key files under `TREE/etc/ssh`, and the
passwd lookup answered from `TREE/etc/passwd`.

- **Buys** native speed, no tracer, no shim, no loader trick, and it is the only
  strategy that reaches **static** binaries, which nothing at run time can trap.
- **Costs** one patch per program, and it is code *you* build; a prebuilt binary
  is out of reach (and falls to M2/M5).
- **Pick it** when the program is small, yours to build, and must run forever
  without a supervisor — a static busybox, dropbear, curl, `tailscaled`.

The honest caveat: the tree becomes the root **for the programs that were
taught**, not for the kernel. Anything not taught still sees the phone's
filesystem. That is not a bug in the method; it is its boundary.

## M10 — nothing foreign at all

Write the tree in POSIX `sh` against the host's own tools, and add no binary that
the host does not have:

- POSIX tools from **one** busybox through a symlink farm (or toybox, if you
  accept per-version drift);
- framework actions through the system binaries (`getprop`, `settings`, `svc`,
  `pm`, `am`, `dumpsys`);
- the tree's own commands as scripts, its state as files, its UI as CGI over the
  same files.

- **Buys** a tree that runs on Android 6 and on Android 16 unchanged, needs no
  loader, no tracer and no privilege, and is small enough to live in a **boot
  image** — the only place that survives a factory reset ([root](root.md)).
- **Costs** you write every command, and there is no package manager: a foreign
  program is still foreign.
- **Pick it** for a device that must keep working without you.

Full recipe, with what broke on the second device:
[a poor-host tree](poor-host-tree.md).

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
| absolute paths inside a static binary | nothing at run time | a source patch (M9) — the only answer for static code |
| service supervision | run services from the host app | a userspace supervisor (`runit`) inside the tree, since there is no PID 1 to give it |
| `execve` on modern Android | — | userland exec (M7) |
| surviving a reboot | a `service.d` hook | |
| surviving a **factory reset** | — | the tree's source in the boot image ([root](root.md#the-durability-ladder)) |

## Decision tree

```
What does the device have to be?
├── a lab device I own, with a root shell ────────────► M1 (chroot + binds).
│                                                        Where state may live: root.md
└── a device that must keep working without me
    ├── small, headless, must survive a factory reset ► M10 (poor-host tree)
    │                                                     + root.md for the boot image
    └── needs real Linux software (apt, compiler)
        Does `unshare -Ur` succeed on the device?   (probe it, do not assume)
        ├── yes ────────────────────────────────────► M3 (userns + chroot)
        └── no
            just one binary? ───────────────────────► M6 (glibc bundle). Ten minutes.
            Is a 2–10× slowdown on metadata acceptable?
            ├── yes ────────────────────────────────► M2 (proot). Most robust.
            └── no ─────────────────────────────────► M5 (hybrid)
                                                      + M7 where the platform
                                                        forbids execve
                                                      + M9 for static binaries
```

Reading paths: [a foreign tree](foreign-tree.md) · [a poor-host tree](poor-host-tree.md)
· [root](root.md).

## Two rules that survive every method

1. **One owner per rule.** If two components each decide what `/etc/passwd`
   means, they will eventually disagree, and the bug will look like a random
   `ENOENT` in one path and not another. Collapse the rule to one
   implementation and make the others clients of it.
2. **A fast path is not the method.** A shim is an optimisation that skips a
   cost; the moment it is the *only* answer for a syscall class, correctness now
   depends on which binaries happen to be dynamic. Always keep the full-coverage
   layer underneath, and be explicit about which programs fall to it.
