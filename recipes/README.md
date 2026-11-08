# Recipes

A recipe is a goal, a short procedure and an expected result. The pages in
[methods](../methods/README.md) explain and cost; these pages say what to type.
Steps are allowed here and only here.

Every recipe carries a **basis**: **run here** means the procedure was executed for
this repository and its output is quoted; **recorded** means it was executed
earlier, on the device and date named, and has not been re-run here — some of them
depend on a component this repository does not ship, and they say so.

## By goal

| goal | recipe | basis | root | isolation |
| --- | --- | --- | --- | --- |
| a tree of commands, no root, no download | [shell-tree](shell-tree.md) | run here | no | 0 |
| an FHS root that runs a static binary | [chroot-busybox](chroot-busybox.md) | run here | yes | 4 |
| an FHS root that runs a dynamic glibc program | [chroot-glibc](chroot-glibc.md) | run here | yes | 4 |
| the Debian files those need, built on a host | [ingredients-debian](ingredients-debian.md) | run here, host | - | - |
| a distribution's glibc with the tree's paths | [glibc-swap](glibc-swap.md) | recorded | no | 1 |
| install Debian packages into a tree | [translate-debs](translate-debs.md) | recorded | no | 1 |
| an entry a launcher can call | [entry-script](entry-script.md) | run here, two phones | no | - |
| a compiler in the tree that links right | [gcc-in-tree](gcc-in-tree.md) | recorded | no | 1 |
| a DSO preloaded by the loader, not the env | [preload-shim](preload-shim.md) | recorded | no | 2 |
| one program and its closure, no tree | [bundle](bundle.md) | recorded | no | 1 |
| point a binary at another loader | [patch-interp](patch-interp.md) | run here, host | - | 1 |
| prefix absolute paths with a preloaded DSO | [symbol-shim](symbol-shim.md) | run here, host | - | 2 |
| answer identity at the symbol layer | [identity-symbols](identity-symbols.md) | run here, host | - | 2 |
| a glibc tree with no root, over adb | [no-root-glibc](no-root-glibc.md) | recorded | no | 1–3 |
| deploy a script tree over adb | [host-tree-deploy](host-tree-deploy.md) | recorded | no | 0 |
| a tree that survives a factory reset | [boot-image-durable](boot-image-durable.md) | recorded | yes | - |
| a full Debian tree with a working package manager | [debian-chroot-full](debian-chroot-full.md) | run here | yes | 4 |
| build a program for the tree on the host | [cross-build](cross-build.md) | run here | yes, needs a tree | 1 |
| one busybox, the same options on every phone | [busybox-farm](busybox-farm.md) | run here, three phones | no | 0 |
| a command with `status`, `check` and `adopt` | [service-verbs](service-verbs.md) | run here, three phones | no | 0 |
| a child process that comes back when it dies | [supervisor](supervisor.md) | run here, three phones | no | 0 |
| change what a raw syscall asks for, on disk or at load | [patch-syscall-site](patch-syscall-site.md) | run here, chroot | yes | 1–2 |
| share memory when the kernel has no SysV IPC | [memfd-shared-segment](memfd-shared-segment.md) | run here, three phones | no | 0 |

## By constraint

| constraint | start with |
| --- | --- |
| no root | [shell-tree](shell-tree.md), [no-root-glibc](no-root-glibc.md) |
| no busybox on the phone | [shell-tree](shell-tree.md), which needs nothing |
| Android 10 or older | [shell-tree](shell-tree.md); `readelf` is absent before Android 12, so the loader checks need another route |
| a rooted phone | [chroot-busybox](chroot-busybox.md), then [chroot-glibc](chroot-glibc.md) |
| about 2 MB of free space | both chroot recipes: 1.7 MB and 2.1 MB |
| no glibc userland to copy files from | [ingredients-debian](ingredients-debian.md): 64 s, 225 MB on a host |
| a libc patch without forking glibc | [glibc-swap](glibc-swap.md): ten files, re-checked per release |
| only a Linux host, no phone | [ingredients-debian](ingredients-debian.md), [patch-interp](patch-interp.md), [symbol-shim](symbol-shim.md), [identity-symbols](identity-symbols.md) |
| a boot image you are willing to risk | [boot-image-durable](boot-image-durable.md), only with a saved original |
| network on the phone for `apt` | [debian-chroot-full](debian-chroot-full.md) |
| a host cross-compiler | [cross-build](cross-build.md) |
| one tool set that behaves the same on Android 10, 12 and 15 | [busybox-farm](busybox-farm.md) |
| no service manager, no root | [service-verbs](service-verbs.md), [supervisor](supervisor.md) |

## The shape of a recipe

1. **Goal**: one sentence, and the isolation level it settles at;
2. **Basis**: run here, or recorded with the device and date;
3. **Prerequisites**: the tools and the phone state it assumes;
4. **Time and size**: how long, how much space;
5. **Steps**: numbered commands, each runnable as written;
6. **Expected**: the output, so it is clear when the recipe is done;
7. **If it fails**: symptom, cause, next check;
8. **Undo**: the commands that put the phone back;
9. **Cost**: what the recipe gives up, in the terms of the
   [isolation scale](../README.md#the-isolation-scale).

## Rules

- **Every recipe states its basis.** "Recorded" is honest; "run here" is better.
- **Every recipe ends with undo.** A recipe that cannot be reversed is not offered.
- **Cleanup order is part of the recipe**: unmount (lazily, for a `/dev` bind), verify
  with `mount | grep`, then delete. Deleting first unlinks device nodes in the live
  `/dev` ([root](../tree/root.md#deleting-a-tree-safely)).
- **Steps are minimal.** A recipe that explains belongs in `methods/`; a recipe that
  guesses is a sketch.
- **No recipe whose last run was on a different Android version from the one in
  your hand, without saying so.**

## Sketches, not recipes yet

The full backlog, with costs and what each candidate would teach, is in
[backlog.md](backlog.md). The table below is the short form: the items with no
run at all, unnumbered on purpose.

These have a design and no run at all. They are unnumbered on purpose: do not
follow one as if it were checked.

| sketch | what would make it a recipe |
| --- | --- |
| a terminal in a tree | a probe of `/dev/ptmx` and `TIOCGPTN` in each domain, and one interactive shell through it |
| the netlink leak | a tree that reads the phone's interfaces, and the same read under a different domain |
| a glibc program without root using only this repository's parts | a runtime that starts the tree on an unrooted phone, and one run of one program |
| a virtual machine as the host (isolation 5) | an AVF device, a tree inside it, and one program's output |
