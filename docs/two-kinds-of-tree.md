# 2. Two kinds of tree

Almost every "Linux on Android" project argues about **how** to run a tree. Very
few ask **which kind of tree** they are building, and that is the choice that
decides everything downstream — including whether root is needed at all.

There are two kinds. They are not competing implementations of one idea; they
answer different questions and they compose.

## A tree is a layout, not a kernel object

A tree is a directory with a stable layout (`bin lib etc var tmp home`), an
entry point, and the rule that a program can find its world by absolute path.
That is all. The kernel knows nothing about it: no mount, no root, no `chroot`
([the problem](the-problem.md)).

FHS is what makes a layout predictable across trees. A tree can be *FHS-shaped*
without being a distribution, and it can be a full distribution without being
FHS-clean. Both are legitimate; they fail differently.

## Kind A — the foreign tree

A userland the phone does not have: Debian `arm64` with glibc, Alpine with musl,
Arch. You import a root filesystem and make it run.

- **Buys** unmodified software: `apt`/`dpkg`, compilers, the archive.
- **Costs** the whole emulation of `/`: a loader that finds the tree, a rule for
  every absolute path, an identity layer. That layer *is* the project.
- **Pick it** when compatibility is the requirement.

Recipe: [4. Build a foreign tree](foreign-tree.md).

## Kind B — the poor-host tree

**Poor host** is the term for a host that gives you `sh`, toybox and a loader —
and nothing else. No glibc, no compiler, no package manager, no `chroot`.

The poor-host tree is built *out of the host's own material*: Android's `sh` and
toybox, one busybox when the host happens to have one (Magisk ships one), and
scripts you write. The tree is a layout plus your commands — a few hundred
kilobytes.

- **Buys** no loader problem, no path translation, no tracer, native speed, a
  floor as old as Android 6, and — the real prize — **places to live** that a
  foreign tree cannot use, up to the boot image, which is the only thing that
  survives a factory reset ([6. Root](root.md)).
- **Costs** you write everything. No `apt`. A foreign binary is still a foreign
  binary, and needs the strategies below.
- **Pick it** when the device has to keep working without you: a router, a node,
  an uplink, a headless box polled over ADB.

Recipe: [5. Build a poor-host tree](poor-host-tree.md).

## What a poor-host tree is made of

| layer | source | why not the obvious alternative |
| --- | --- | --- |
| POSIX tools | **one busybox**, reached through a symlink farm | toybox applets and options change between AOSP versions, so behaviour depends on the phone; one busybox makes the tree behave the same everywhere |
| shell | Android's `mksh`, scripts written in POSIX sh | it is already there, it is the shell `init` uses, and there is nothing to ship |
| framework actions | the system binaries: `getprop settings svc pm am dumpsys logcat` | they are the platform's own interface; copying their behaviour is how trees rot |
| your commands | `bin/<name>` scripts, one verb set each | a command is a file, so it can be read, edited and called over ADB |
| state | `etc/` (intent) and `var/` (generated) | see the state rule below |
| UI | a CGI web frame over the same files | the UI must not own anything the tree cannot do |
| supervisor | a shell loop with a respawn policy | there is no PID 1 to delegate to |
| durability | wherever the source lives: a `service.d` hook, or the boot image | the location *is* the durability |

The layout is deliberately FHS-shaped (`bin lib etc var tmp home`) rather than a
copy of `/system`: it gives scripts one stable set of paths, and it leaves room
for a foreign tree to sit beside it later.

## The four path strategies

Whichever kind of tree you build, there are exactly four ways a program can find
it. Every project in [prior art](prior-art.md) is a choice among these.

| # | strategy | who does the work | what it costs | works for |
| --- | --- | --- | --- | --- |
| 1 | **emulate `/`** — a tracer or a preloaded library maps every absolute path | a runtime | a stop per traced call, or a coverage hole | foreign binaries, unmodified |
| 2 | **rewrite the entry** — `PT_INTERP`, shebang, launcher | an install-time text or ELF edit | cheap and permanent; brittle when the tree moves | any ELF or script you can edit |
| 3 | **teach the program** — build it so the paths it owns point into the tree | the person building it | one patch per program | code you build: busybox, dropbear, curl, your own |
| 4 | **use the host's own libc** — write shell, or build against bionic | nobody | you write it | scripts and your own tools |

Strategies 1 and 2 are what make a foreign tree possible. Strategies 3 and 4 are
what make a poor-host tree possible — and they are also what make it *cheap*:
nothing sits between the program and the kernel.

**Strategy 3 is the one people forget.** A static binary cannot be trapped by a
tracer and cannot be told about the tree by the environment, so the usual answer
is "static binaries are a gap". They are not: a static binary can be **taught**.
Build it (or patch it) so that the absolute paths it owns become paths in the
tree — `TREE/home` for `getpwnam`, `TREE/etc/ssh` for host keys, `PATH` starting
with `TREE/bin` — and it runs with no `chroot`, no mount and no tracer, at full
speed. That is how a musl dropbear became part of a tree on the reference
device: one patch, four paths, no privilege.

This is also the honest reading of "the tree becomes an FHS root without
chroot": it is the root *for the programs that were taught about it*, not for
the kernel. Programs you did not teach still see the phone's filesystem.

## The second axis: state

Two kinds of state live around a tree, and mixing them is the most common
durability bug ([6. Root](root.md)):

| state | example | who owns it | what the tree does |
| --- | --- | --- | --- |
| **the platform's** | `settings`, package state, tether state, radio band, battery policy | the framework | never keeps a copy; reads and writes it through `settings`/`pm`/`svc`/`cmd` |
| **the owner's intent** | desired profile, debloat list, feature flags, thresholds | **the tree** | one file per thing in `etc/`; a boot script reads the intent and applies it |

The consequence is a rule worth memorising: **a boot script is a controller, not
a store.** Intent lives in files; the platform's state is re-applied at every
boot. A tree that caches the platform's state will be wrong after the first
thing it did not observe.

## Choosing

| the question | kind | where it lives |
| --- | --- | --- |
| "I need `apt`, a compiler, unmodified software" | A | app data, `/data/local/tmp`, or a root filesystem |
| "It has to survive a factory reset and run headless" | B | the boot image, restored into `/data/adb` at boot |
| "It has to start other things and stay out of the way" | B, starting A | both, side by side |
| "I need one foreign binary, not a system" | neither | a loader bundle ([prior art](prior-art.md)) |

A cluster node, a router, an uplink: **B**. A development environment on the
phone: **A**. A device that is both: B at the bottom, A inside it, and the
layouts kept compatible on purpose.
