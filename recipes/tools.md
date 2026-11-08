# What you cook with

Every recipe here assumes a small set of tools. There is more than one choice for
most of them, and the choice changes what a recipe costs. This page lists the
choices and the defaults the recipes use.

## Where you cook: the phone, or a host

| kitchen | what it is good for | what it cannot do |
| --- | --- | --- |
| **the phone** (`adb shell`, Termux) | editing and running the tree, a root shell, the run itself | `patchelf`; `readelf` before Android 12; building a Debian userland without network tricks |
| **a Linux host** (WSL, a PC, a server) | the ingredients: `debootstrap`, `patchelf`, `gcc`, `strace`, the ELF tools | nothing that needs the phone: the kernel, the domain, the actual run |

The recipes use both: ingredients on the host, the run on the phone. A phone-only
kitchen is possible, and slower.

## The ingredients, and where they come from

| ingredient | usual source | the recipe that needs it |
| --- | --- | --- |
| a **static busybox** | the rooting tool ships one, usually at `/data/adb/magisk/busybox` | [chroot-busybox](chroot-busybox.md) |
| a **glibc userland** | [ingredients-debian](ingredients-debian.md): `debootstrap --foreign`, 64 s and 225 MB | [chroot-glibc](chroot-glibc.md) |
| a **program to run** | a static build, or one you compile for bionic | [static-binary](../methods/static-binary.md), [rebuild](../methods/rebuild.md) |
| nothing at all | the phone's own `sh` and toybox | [shell-tree](shell-tree.md) |

## The tools, by purpose

| purpose | tool | where it runs | alternative |
| --- | --- | --- | --- |
| read an ELF's loader | `readelf -l` | Android 12 and later; always on a host | the host, for an older phone |
| rewrite `PT_INTERP` | `patchelf` | a host only | a hex edit, or a build that names the tree ([rebuild](../methods/rebuild.md)) |
| build a userland | `debootstrap --foreign` | a host, or Termux | `mmdebstrap`, or a distribution tarball |
| move files | `adb push`, `adb pull` | a host | a tar stream over `adb`, or `adb` over TCP |
| inspect what a process sees | `/proc/self/status`, `/proc/self/attr/current` | the phone | [probe.sh](../examples/probe.sh) does the same sweep |
| count or trace syscalls | `strace` | a host | the runtime's own counters on the phone |
| time a run | `date +%s` around the command | either | the host's `time`, which is not in Android's `sh` |
| edit text | `sed -i`, a here-document | either | the host, then push |

## What you do not need

- **`qemu-user-static`** for the glibc ingredient: `--foreign` only extracts.
- **the NDK** unless the recipe rebuilds a program.
- **root** for [shell-tree](shell-tree.md); a PC for the same recipe, if the
  phone is in your hand.
- **busybox** for [shell-tree](shell-tree.md), or for any tree that only runs
  static binaries.

## The one precondition every recipe shares

Run `examples/probe.sh` first, or at least `id -u` and `Seccomp:` from
`/proc/self/status`. A recipe that assumes root on a shell-domain phone fails at
the first `chroot`, and the failure looks like a missing file.
