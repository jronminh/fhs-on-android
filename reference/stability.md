# What a tree may rely on

Two families of facts stand under every method in this guide: those that will
not move under it, and those that move with a release. Telling them apart is
what decides whether to change a program, interpose a symbol, key on a syscall
number, or patch an instruction.

## Very stable

- **The syscall numbers.** arm64 uses one generic table: a number means the same
  syscall on every arm64 kernel, and kernels only add — no number is reused
  ([syscalls.md](syscalls.md)) [s]. A policy or a filter keyed by number rests on
  a permanent contract.
- **The interface.** `x8` holds the number, `x0..x5` the arguments, the result
  returns in `x0`; the semantics are documented "Linux 1.0+", and a syscall is
  removed essentially never [s].
- **The A64 base instructions.** `svc`, the general-purpose registers and the
  program counter are permanent; later architecture versions add (SVE, LSE), they
  do not change the base, and every instruction is 4 bytes — which is why a
  rewrite of one instruction is clean [s].
- **`seccomp_data.instruction_pointer`** is an architected field: the program
  counter at the call [s]. A rule keyed on it rests on the ISA, not on a
  program's code.

## What moves

- **glibc's internal code.** Which function holds the `svc`, the exact
  `mov x8,#nr; svc` sequence, whether the cancellable path keeps the number in
  `x6` — a compiler's and a source's output, and different between glibc
  versions [s]. A [patched site](../recipes/patch-syscall-site.md) sits here.
- **A library's symbol set.** Mostly stable, but it is a library's contract, not
  the kernel's [s].
- **The platform's policy.** Which numbers the app's filter kills is a release's
  decision: 32 real denials on Android 12, 42 on 16 ([syscalls.md](syscalls.md)).
- **The phone's own tools.** toybox's applets and options differ between AOSP
  versions, which is why a tree that must behave the same pins one busybox
  ([the host's own material](../tree/bionic.md)) [m].
- **The page size.** 4 KB historically, 16 KB on some 2024+ devices; a build that
  assumes 4 KB is a build-system property, not a runtime one [s]/[u].
- **The app rules.** `execve` of app data refused from `targetSdk` 29, and the
  filter's contents by release ([domains](domains.md)).

## What follows for each method

| the method | what it leans on | how it ages |
| --- | --- | --- |
| [symbol interposition](../methods/loader.md) | the library's symbols | stable; no instruction is edited |
| a filter or policy keyed by number | the syscall ABI | stable; a new call is a new row |
| [a patched `svc` site](../recipes/patch-syscall-site.md) | glibc's code layout | version-fragile; a wrong pick costs a plain `svc`, no worse |
| [a patched package](../methods/patch-package.md) | the tree's path | fragile to the tree moving, stable to a release |
| [a rebuilt program](../methods/rebuild.md) | the source | the most durable, and the most work |
| [a static binary](../methods/static-binary.md) | the kernel's ABI | durable; ages with the kernel, not the platform |

The rule that falls out: **prefer what reads the ABI or the ISA over what reads a
particular instruction sequence**, and prefer a symbol to an instruction when a
symbol exists. The instruction set is not the fragile part; some program's code
is.

## The shelf life of an assumption

A tree that assumes a `targetSdk` of 28, a 4 KB page and a release's filter has a
shelf life, and each assumption has a different date on it. The ones written here
are the ones measured or read at the top of 2026-11; re-read them per release,
and check the two that this guide has not measured: the 16 KB page's exact
failure per build system, and the filter's set on a device newer than Android 16
[both [u]].
