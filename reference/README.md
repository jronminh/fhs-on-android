# Reference

The other pages say what to do. These say what is true on a phone, and how it was
established: the platform model, the failures it produces, and the evidence behind
each claim.

| page | what it answers |
| --- | --- |
| [problem.md](problem.md) | why a glibc tree and Android disagree at all — the three gates, and why a refusal is not a setting |
| [syscalls.md](syscalls.md) | which calls the kernel lacks and which the filter kills, counted per kernel and per device |
| [mechanisms.md](mechanisms.md) | what the kernel and the host offer a tree: a PTY, shared memory, netlink, a supervisor, and what leaks |
| [stability.md](stability.md) | what a method may build on (the syscall ABI, A64) and what moves (glibc's code, the platform's policy) |
| [glibc-build.md](glibc-build.md) | building the tree's own glibc from source: LFS's bootstrap, its neighbours, and what it costs |
| [surfaces.md](surfaces.md) | every place a program can read a path or an id, and which layer can answer each |
| [devices.md](devices.md) | the phone's `/dev` as a tree sees it: which nodes exist, who may open them, and what a missing one costs |
| [domains.md](domains.md) | app, shell and root: which gates a process meets, and what each domain decides |
| [limits.md](limits.md) | the failure catalogue: symptom, cause, next check, and the cheapest fix that does not misrepresent the phone |
| [measure.md](measure.md) | how to make a number taken on a phone worth quoting |
| [evidence.md](evidence.md) | the devices this guide was run on, and the meaning of every label |
| [examples.md](examples.md) | every file in `examples/`, what it demonstrates, and how to check it |
| [prior-art.md](prior-art.md) | what has been built before, which question it answered, and what it teaches |

Two habits hold the whole guide to this: every non-obvious sentence carries a label
(**m**, **s** or **u**, defined in [the README](../README.md#labels)), and a claim
this repository has not run is labelled as one it has not run. A page here that
states a platform fact without a label is a bug
([CONTRIBUTING](../CONTRIBUTING.md)).
