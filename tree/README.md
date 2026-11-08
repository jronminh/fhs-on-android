# The tree

A tree is a directory with a stable layout — `bin lib etc var tmp home` — an
entry point, and the rule that a program can find its world by absolute path.
That is all. The kernel has never heard of it: no mount, no `chroot`, no root
([reference/problem.md](../reference/problem.md)).

FHS is what makes the layout predictable. A tree can be *FHS-shaped* without
being a distribution, and a distribution without being FHS-clean. Both are
legitimate; they fail differently.

## Two ways to fill it

| supply | what you get | page |
| --- | --- | --- |
| **a glibc userland** | unmodified Linux programs, a package manager, compilers | [glibc.md](glibc.md) |
| **the host's own material** | scripts and the phone's own tools, nothing foreign | [bionic.md](bionic.md) |

They compose: a bionic tree can start a glibc one, keep its state, and restore it
after a reset ([durability.md](durability.md)).

## What a directory needs to be a tree

A layout is not a tree until these exist and work: a loader that finds it;
something that answers every path the kernel and libc resolve; an identity layer;
`/dev`, `/proc`, `/sys`; `/etc/resolv.conf`; a writable `/tmp` and `/var`;
`/etc/passwd`, `group`, `shadow`; and a supervisor, because there is no PID 1 to
delegate to ([reference/problem.md](../reference/problem.md#what-a-directory-needs-to-be-a-tree)).
The methods pages answer these one at a time.

## The four path strategies

Whichever supply you pick, there are four ways a program can find the tree. They
are the same four the [method pages](../methods/README.md) build on:

| # | strategy | who does the work | what it costs | works for |
| --- | --- | --- | --- | --- |
| 1 | **emulate `/`** — a tracer or a preloaded library maps every absolute path | a runtime | a stop per traced call, or a coverage hole | foreign binaries, unmodified |
| 2 | **rewrite the entry** — `PT_INTERP`, shebang, launcher | an install-time edit | cheap and permanent; brittle when the tree moves | any ELF or script you can edit |
| 3 | **teach the program** — build it so the paths it owns point into the tree | the person building it | one patch per program | code you build |
| 4 | **use the host's own libc** — write shell, or build against bionic | nobody | you write it | scripts and your own tools |

Strategies 2 and 4 are what make a tree cheap; strategies 1 and 3 are what make
foreign programs run. Every method is a position on this table.

## State

Two kinds of state live around a tree, and mixing them is the most common
durability bug:

| state | example | who owns it | what the tree does |
| --- | --- | --- | --- |
| **the platform's** | `settings`, package state, tether state, radio band | the framework | never keeps a copy; reads and writes it through `settings`/`pm`/`svc`/`cmd` |
| **the owner's intent** | desired profile, debloat list, feature flags | **the tree** | one file per thing in `etc/`; a boot script applies it |

The rule that follows: **a boot script is a controller, not a store.**

## Where it lives

On a **rooted** phone the contract changes again: identity is real, `chroot` works,
and the durability ladder has a top rung ([root.md](root.md)).

Where the tree lives decides whether it comes back
([durability.md](durability.md)): app data and `/data/local/tmp` survive a
reboot; `/data/adb` survives one too; only the boot image survives a factory
reset, and it is where the tree's **source** — not the tree — belongs.
