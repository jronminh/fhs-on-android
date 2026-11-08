# The methods

Everything here exists to answer one question: **how does a program that knows
nothing about Android come to run inside the [tree](../tree/README.md)?** Each
page is one answer, and each answer has a price. The price this guide cares about
most is [isolation](../README.md#the-isolation-scale): how many things end up
standing between the program and the phone. Every method below is valid; the
pages state what it buys, what it costs, and when you would pick it.

| method | isolation | what it is | one-line price |
| --- | --- | --- | --- |
| [scripts](scripts.md) | 0 | the host's own `sh` and tools, one file per command | you write every command |
| [static binary](static-binary.md) | 0 | a binary that needs no libc at all | it sees the phone's filesystem |
| [rebuild](rebuild.md) | 0–1 | own the build, against bionic or the tree's glibc | you need the source |
| [patch package](patch-package.md) | 1 | edit the files: `PT_INTERP`, shebang, rpath, repack | the path is baked |
| [own libc](own-libc.md) | 1 | patch or build the libc itself | you maintain it |
| [loader shim](loader.md) | 0–2 | a preloaded DSO, and a loader that derives its prefix | blind spots |
| [exec](exec.md) | 2 | map the program yourself when the kernel refuses | the ELF loading contract |
| [identity](identity.md) | 2–3 | answer `uid`, `chown`, setuid across the surfaces | one owner, or contradictions |
| [tracer](tracer.md) | 3 | `ptrace` + seccomp, or proot | a stop per call |
| [chroot](chroot.md) | 4–5 | namespaces, `chroot`, a VM | privilege, and Android goes out of reach |

Every method below has an artifact behind it: a file that ran on a phone
([the examples](../reference/examples.md)).

## What every method must answer

A program asks the same few things of any environment. A method is a choice of
who answers, and leaving one unanswered is a known hole:

1. **where am I** — the loader that finds the tree ([tree](../tree/README.md));
2. **where are my files** — every absolute path, including the ones libc resolves
   inside itself (NSS, `gconv`, `ld.so.cache`);
3. **who am I** — [identity](identity.md), because packages and `sudo` check;
4. **may I start** — [exec](exec.md), which is not free in the app domain;
5. **what did the kernel refuse** — the gates
   ([reference/problem.md](../reference/problem.md#the-three-gates)).

## How to choose

1. **The domain first** ([reference/domains.md](../reference/domains.md)): an app
   brings Gate A and the `execve` rule; the shell brings neither; root brings
   capabilities. A method that works in one domain can be impossible in another.
2. **Then the lowest isolation you can afford.** Prefer changing the program
   ([rebuild](rebuild.md), [static](static-binary.md)) over wrapping it
   ([shim](loader.md), [tracer](tracer.md)) — the wrapper is what makes the tree
   stop feeling like Android.
3. **Then the price you can keep paying.** A tracer is cheap per program and
   expensive to maintain; a rebuilt program is the reverse.

## Two costs that bite every method

Neither is a rule about which method to pick; both are bills you pay whichever one
you pick.

1. **The path rule must have one owner.** Two components deciding what
   `/etc/passwd` means will disagree, and the bill arrives as a random `ENOENT` on one
   path and not another.
2. **A fast path leaves holes.** A shim skips a cost; where it is the only answer
   for a syscall class, coverage depends on which binaries happen to be dynamic.
   The bill is a bug that appears with the first static program in the tree.

## What this guide has not tried

- **`chroot` and user namespaces** ([chroot.md](chroot.md)) — level 4 is designed but
  never built here; the kernels probed answered `unshare(CLONE_NEWUSER)` with
  `EINVAL`/`EPERM` [m].
- **A virtual machine** (level 5): [prior art](../reference/prior-art.md).
- **musl**: out of scope, with its reason in
  [reference/problem.md](../reference/problem.md).
