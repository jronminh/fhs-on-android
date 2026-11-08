# Exec

Isolation **2**. Sometimes the question is not what a syscall means but whether the
program starts at all: an app targeting API 29+ may not `execve` files in its own
data directory, and that refusal is SELinux policy, not an `errno` a program can
catch. The answer is to stop asking the kernel.

## What it buys

- **The only route** when `execve` of app data is refused - no `targetSdk` 28 escape
  hatch required.
- **Syscall patching in memory the process owns**, so no `execmod` is needed.
- **A fast path for static binaries**, which no preload can reach.

## What it costs

- **The ELF loading contract becomes yours**: `auxv`, stack layout, `AT_EXECFN`,
  `PT_INTERP`, and the loader's own expectations. One wrong field is a segfault with
  no message.
- **The tracer has to be told**: a userland exec does not emit `PTRACE_EVENT_EXEC`,
  so the runtime must synthesise it.
- **A measured trade, not a free win**: 44% fewer stops but about 5% slower wall on
  the workload measured [m] - the stops were not that workload's bottleneck.

## Example

The contract, in the fields a userland exec has to build itself:

```c
#define AT_EXECFN 31
/* the loader named by PT_INTERP is mapped and jumped to, not exec'd */
av[n].k = AT_EXECFN; av[n++].v = (u64)execp;   /* the kernel would have written this */
```

One missing or wrong field is a segfault with no message - there is no `errno` to
read afterwards, which is what makes this method expensive to get right.

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| a segfault with no message, immediately | a field of the loading contract is wrong (`auxv`, stack, entry) | compare against a working `execve` of the same program |
| `Exec format error` | the image is not the architecture, or not ELF | `readelf -h` |
| the child sees a different environment or `argv[0]` | `AT_EXECFN` or the stack was built wrong | print `/proc/self/cmdline` and `/proc/self/environ` from the child |
| the tracer loses the process | `PTRACE_EVENT_EXEC` was never synthesised | re-arm the tracer at the handoff |

## By domain

Only the **app** domain needs it, and only from `targetSdk` 29
([reference/domains.md](../reference/domains.md)). In **shell** and **root** it is a
speed choice, kept because one binary has to serve all three.

## Evidence

The stop and wall figures are measured on a reference device [m]; the
`PTRACE_EVENT_EXEC` requirement is read from the kernel's ptrace interface [s].
