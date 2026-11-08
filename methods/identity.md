# Identity

Isolation **2-3**, depending on the carrier. Identity is not one surface: a program
asks "who am I" in at least five ways, and no single technique reaches all of them.

## What has to be true

- `id` says `uid=0(root)`;
- `chown` reports success and the next reader agrees about the owner;
- setuid bits are honoured, because `passwd`, `sudo` and every maintainer script
  expect them;
- `/etc/passwd`, `group`, `shadow` exist in the tree and agree with the answers;
- a program that *verifies* privilege fails, and the failure is not hidden.

## The model

- **One real uid, virtual principals.** The kernel has one uid per process; every
  other id — `root`, `www-data`, a group — is a name in `/etc/passwd` and
  `/etc/group`, which is the tree's file. So "who am I" is answered twice, by the
  kernel (one number) and by the files (many names), and the two must agree.
- **There is no separate root mode.** Whether a process is root is its effective
  uid; every decision keys on that, so a layer that fakes `geteuid` has to fake it
  for every reader, and a setuid bit is a change of euid at `exec` — which is why
  the setuid bit is a gate and not a flag [s].
- **Tree-root is not real root.** A program that checks with a privileged call
  (`setuid`, `mount`, an owner read back through the kernel) gets the kernel's
  answer, and the kernel does not know about the tree [s]. Those are the rows the
  failure catalogue collects.

## Which carrier answers which check

| the check | answered by | what it costs |
| --- | --- | --- |
| `getuid`/`geteuid` from a dynamic program | the [loader shim](loader.md), at the symbol | nothing per call |
| `getuid` from a static program or raw syscall | the [tracer](tracer.md) | one stop |
| `chown`, `chmod` on the tree's files | the carrier answers "success"; the real owner does not change | an answer the file system can contradict |
| file ownership at all | the [package](patch-package.md): ownership recorded when the tree is built | a table to keep in step |
| setuid bits after a copy | the build records them; the boot restores them | a step that is easy to forget |
| a real second uid | nothing: the kernel has one uid per process | a platform limit |

## What it costs

- **A second truth**: whatever answers `getuid` must be the same thing that answers
  `chown` and that wrote `/etc/passwd`. Two of them will disagree.
- **It is never real outside root**: the checks that go to the kernel (`setuid`,
  `mount`) fail, and the failure is visible rather than hidden.
- **A table to carry**: ownership and setuid bits recorded at build and restored
  at boot ([tree/durability.md](../tree/durability.md)).

## Example

[examples/identity.c](../examples/identity.c) answers identity at the symbol layer, in a dozen lines; the file system still
disagrees.

```c
uid_t getuid(void)  { return 0; }
uid_t geteuid(void) { return 0; }
int chown(const char *path, uid_t owner, gid_t group)
{
    (void)path; (void)owner; (void)group;
    return 0;
}
```

The comment at the top of the file names the checks that still fail: `setuid()`
as a real syscall, `mount()`, and any owner read back through the kernel.

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `whoami` says root and `id` says `u0_aNNN` | two owners answered | collapse them: one carrier, one `/etc/passwd` |
| `chown: Operation not permitted` | no `CAP_CHOWN`, and no carrier answered | check the carrier is on for that program (shim vs tracer) |
| `setuid()` returns `EPERM` from a "root" shell | the process is not privileged; `setuid` cannot be faked at the symbol layer | answer it at the boundary, or accept the failure |
| `sudo: must be setuid root` after a copy | the setuid bit was dropped by `tar` or `adb push` | restore the recorded bits at boot |
| a shim answers `getuid` but `chown` still fails | the program called `fchownat`, not `chown` - a different symbol | cover the symbols the program actually uses; a symbol-level answer covers only the symbols that are provided [m, 2026-11-08] |

## By domain

In **root** the identity is real and nothing is faked. In **shell** and **app**
every answer above is constructed, and the boundary is the only carrier that can
answer for static code ([reference/domains.md](../reference/domains.md)).

## Evidence

One real kernel uid with virtual principals above it, and `sudo`/`su`/`passwd` that
work, is a design that has been built [s]; the failure rows are in
[limits](../reference/limits.md#identity).
