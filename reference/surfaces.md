# Every reader of a coordinate

A path or an id is not one surface: a program can read a coordinate in many
places, and a tree that answers one and not another is a tree a program can see
through. The rule that follows is short: **a value is mapped only when every
reader of it is mapped**. This page is the checklist — one row per reader — so a
hole is a hole somebody named, not one nobody looked for.

It is what makes the [loader shim](../methods/loader.md)'s and the
[tracer](../methods/tracer.md)'s blind spots concrete: each row says who can
answer it, and a row whose answer is "the host" is the row a program uses to
find the phone.

## Path in

| reader | who can answer |
| --- | --- |
| every syscall with a path argument — `openat`, `newfstatat`, `readlinkat`, `mkdirat`, `unlinkat`, `execve`, ... | a shim symbol for the calls that have one; the tracer for the rest, and for a raw `syscall()` |

That split is the whole argument for the tracer being *under* the shim: the shim
answers the symbols a dynamic program calls, and the syscalls a program issues
around them are the tracer's.

## Path out — the kernel naming a path

| reader | who can answer |
| --- | --- |
| `getcwd` | the shim, or the tracer at the call |
| `readlink`/`readlinkat` targets | the same, on the way out |
| `/proc/<pid>/cwd`, `/proc/<pid>/exe`, `/proc/<pid>/fd/<n>` | a synthesized file, or a mapped readlink |
| `/proc/<pid>/mounts`, `mountinfo`, `/etc/mtab` | a synthesized file — the kernel's answer names the host's mounts |
| `/proc/<pid>/maps`, `smaps` (file-backed lines) | a synthesized file |
| `getdents64` names | the tree's directory listing (leaf names are the tree's; a host row lists the host's, on purpose) |
| `statx` | no name is returned, so nothing to map |

## Descriptors

| reader | who can answer |
| --- | --- |
| `/proc/<pid>/fd/<n>` | a synthesized link |
| `fstat`/`statx` on an open fd | the identity layer, if the owner is faked |
| `fgetxattr`/`flistxattr` | a synthesized label, if one is claimed |
| `fdinfo` | nothing: no path in it |

## AF_UNIX

| reader | who can answer |
| --- | --- |
| `bind`, `connect`, `sendto`, `sendmsg` — the path going in | the tracer (the address is in the program's memory, not in an argument the shim can rewrite) |
| `getsockname`, `getpeername`, `accept`, `recvfrom`, `recvmsg` — the path coming back | the tracer, on the way out |

There is no symbol-level answer here: a shim can rewrite a `char *`, not a
`sockaddr_un` the kernel fills in. This is the clearest case where a method's
coverage is decided by the surface, not by the effort.

## The views the kernel keeps

| surface | who can answer |
| --- | --- |
| the mount view — `mounts`, `mountinfo`, `/etc/mtab` | a synthesized file |
| `maps`/`smaps` | a synthesized file |
| `/proc/<pid>/status`: `Name`, `State`, `Uid`, `Gid`, `CapPrm/Eff/Bnd`, `TracerPid`, `Seccomp` | a synthesized file — the last two are the runtime's own traces, and a tree without a runtime has nothing to synthesize them from |
| `/proc/<pid>/cmdline`, `comm` | a synthesized file when a launcher added itself to the command line |
| `PPid`, `getppid()` | a structural residue no layer removes without lying about the process tree |

## The rest of the host

| surface | who can answer |
| --- | --- |
| `/proc`, `/sys`, `/dev` | the host's, on purpose (the phone's kernel and nodes) |
| `/data`, `/storage`, `/sdcard`, `/mnt`, `/system`, `/apex`, `/vendor` | `ENOENT` inside a tree that does not bind them; a bind reaches one on purpose |
| `openat2` with `RESOLVE_*` | a refusal (`ENOSYS`), because the flags ask for a resolution the shim cannot reproduce; without a resolve flag it runs as `openat`, mapped |

## The test

A tree is covered when a probe that prints its view of every row above comes
back with the tree's values and none of the host's: the tree's own path, the
app's data directory, the shared storage, the tracer's pid. Run it against the
tree, not against a method's claim — the rows are what a method is judged by.

[examples/probe.sh](../examples/probe.sh) answers the first half (which domain,
which gates, which nodes); it does not walk the surfaces above.

## What it means for choosing a method

- **A shim alone cannot be complete**: symbols cover path-in for dynamic
  programs, not path-out, not AF_UNIX, not `/proc`, not a raw `syscall()`.
- **A tracer alone can be complete and slow**: every row above is a stop, which
  is the cost in [the tracer](../methods/tracer.md).
- **A tree with no layer at all** (level 0) has every row answered by the host,
  by definition; that is the trade, not a bug
  ([the isolation scale](../README.md#the-isolation-scale)).
- **A `chroot` moves all of them at once**, because the kernel is then the
  thing naming paths — the reason level 4 is worth root
  ([chroot](../methods/chroot.md)).

## Evidence

- **[s]** the rows, and which layer can answer each: the project's coverage
  checklist and its per-row answers, read in source.
- **[u]** the clean run (`scripts/measure/coverage.sh` and its probe) is the
  project's, on its own device; this guide has not re-run it.
