# Running a Linux program in an FHS tree on Android

Two sentences are the whole repository.

1. **Build an FHS tree on Android** — a directory with `bin lib etc var` that a
   program can call its root ([tree/](tree/README.md)).
2. **Make a Linux program that knows nothing about Android run inside it** — and
   say what each way of doing that costs ([methods/](methods/README.md)).

Every method is an answer to the second sentence, and every answer has a cost.
The axis this guide uses for cost is **isolation**: how many things stand between
the program and the phone. Isolation is counted as a cost, because a tree on
Android exists to use the device's kernel, hardware and services, and each layer
between them reduces what the program can reach.

## The isolation scale

| level | what stands between the program and Android | typical method | what it costs |
| --- | --- | --- | --- |
| **0** | nothing | [scripts](methods/scripts.md), [static binaries](methods/static-binary.md), a [rebuilt program](methods/rebuild.md) | nothing |
| **1** | build time only | [patched package](methods/patch-package.md), [own libc](methods/own-libc.md) | the source, or the file |
| **2** | a preloaded DSO, in the process | [loader shim](methods/loader.md) | blind spots: static binaries, raw syscalls |
| **3** | a tracer at the syscall boundary | [tracer](methods/tracer.md), proot | a stop per call |
| **4** | namespaces, `chroot` | [chroot](methods/chroot.md), userns | privilege; Android's services and nodes go out of reach. `chroot` works on a rooted phone, `unshare -Ur` is refused even there [m] |
| **5** | a virtual machine | AVF | the phone becomes a host, not a platform |

A *glibc* program cannot run unmodified at level 0: it needs its loader found,
which is level 1 at most. The trade is direct: lower isolation means changing the
program rather than the environment. A rooted phone changes the contract, not the
scale: identity stops being faked and level 4 becomes real ([tree/root.md](tree/root.md)).

## The methods, side by side

| method | isolation | cost per program | coverage | speed | maintenance |
| --- | --- | --- | --- | --- | --- |
| [scripts](methods/scripts.md) | 0 | none | only what the host has | native | low |
| [static binary](methods/static-binary.md) | 0 | none | static builds only | native | low |
| [rebuild](methods/rebuild.md) | 0–1 | the source | only code you can build | native | medium |
| [patch package](methods/patch-package.md) | 1 | low, breaks when the tree moves | any editable ELF or script | native | medium |
| [own libc](methods/own-libc.md) | 1 | hours, once | everything a libc answers | native | high |
| [loader shim](methods/loader.md) | 0–2 | none | dynamic glibc | near native | medium |
| [tracer](methods/tracer.md) | 3 | none | everything | slow on metadata | high |
| [exec](methods/exec.md) | 2 | none | what the kernel refuses to exec | native | medium |
| [identity](methods/identity.md) | 2–3 | none | the checks the carrier reaches | native | medium |
| [chroot](methods/chroot.md) | 4–5 | low | everything | native | high |

Moving down the table gains compatibility and loses reach. A tree usually
combines two or three rows, and the same program carries a different cost in each
domain.

## Evidence in the repository

Each method page is paired with a file in `examples/`, and each claim is
labelled: measured, read in a specification, or unverified. Some pairs:

| claim | example in this repository |
| --- | --- |
| a command is a file, and `check` answers a question | [examples/cmd.sh](examples/cmd.sh) |
| `PT_INTERP` is one field, and rewriting it is a loop | [examples/elf-interp.sh](examples/elf-interp.sh) |
| a path shim is small, and its blind spots are structural | [examples/shim-open.c](examples/shim-open.c) |
| identity can be answered at the symbol layer, and the kernel still disagrees | [examples/identity.c](examples/identity.c) |
| the isolation the platform allows is two commands away | [examples/isolate-check.sh](examples/isolate-check.sh) |
| a loader that the tree names is one `readelf` away | [examples/which-loader.sh](examples/which-loader.sh) |

[reference/examples.md](reference/examples.md) is the index: every example, what it
demonstrates, and how to check it.

## What no method can skip

A program asks the same few things of any environment, and a method is only a
choice of who answers: the loader ([tree](tree/README.md)), every absolute path,
the identity ([methods/identity.md](methods/identity.md)), the right to be
`exec`ed ([methods/exec.md](methods/exec.md)), and the kernel's refusals
([reference/problem.md](reference/problem.md)). Leaving one unanswered is a known
gap that the page names.

## Scope

Two supplies of programs, one tree: a **glibc userland** you import
([tree/glibc.md](tree/glibc.md)) and the **host's own material**
([tree/bionic.md](tree/bionic.md)). musl is out of scope with its reason in
[reference/problem.md](reference/problem.md). Debian is the measured supply; the
contracts are the same for any glibc userland.

The methods are assembled from several implementations; public ones are listed
as [prior art](reference/prior-art.md), not as dependencies.

## Labels

Every non-obvious statement is labelled:

- **[m]** — measured on one of the devices in [evidence](reference/evidence.md), on a named date;
- **[s]** — read in a specification or in source (AOSP, glibc, the kernel);
- **[u]** — unverified assumption, or a report this guide has not reproduced.

## Status

2026-11, pre-alpha, one maintainer, no CI. What is measured and what is next is
kept in [TODO.md](TODO.md). Corrections with a device and a date
are the most useful contribution ([CONTRIBUTING.md](CONTRIBUTING.md)). Text is
CC BY 4.0, scripts MIT ([LICENSE](LICENSE)).
