# 7. Prior art

Everything here has been done before, in at least six different ways. Knowing
which one a project chose — and why — saves you from re-deriving its bug list.

| project | method | root | real FHS tree | teaches |
| --- | --- | --- | --- | --- |
| [proot](https://proot.gitlab.io/proot/) | `ptrace` path/identity translation | no | yes | M2 is the most *portable* answer: it catches static binaries, raw syscalls and `execve` because it sits at the only boundary nothing can escape. Its cost is a stop per traced call, paid forever. |
| [proot-distro](https://github.com/termux/proot-distro) | proot + a distro installer on Termux | no | yes | the ten-minute path to a working tree; also that the tree's own install scripts need patching for proot (`chown`, `useradd` in `debootstrap`) — evidence that assumption 4 (uid 0) is load-bearing, not cosmetic |
| [Termux](https://github.com/termux/termux-app) + termux-packages | native bionic packages, no tree | no | no | the platform runs fine when you stop fighting it: the cheapest "Linux on Android" is often *not* an FHS tree |
| [glibc-runner](https://github.com/termux-pacman/glibc-packages) and the Termux `glibc` bundles | a foreign glibc + patched loader beside Termux's prefix | no | no | M6 is the right tool for a *binary* and the wrong tool for a *system*: no `dpkg`, no dependency graph, no `/usr/share` |
| Linux Deploy | root, `chroot` + loop image | yes | yes | M1 is the clean answer, and its popularity is why so many instructions silently assume root |
| Andronix, UserLAnd | proot/chroot + a UI and a store | no | yes | a runtime with no packaging story loses to one with an installer; the hard part for users is never the syscall layer |
| [Termux:X11](https://github.com/termux/termux-x11) | X11 server as an app, over a socket | no | yes | the display is a *device* problem with its own protocol; do not fold it into the path layer |
| Waydroid, Anbox | LXC/container running Android on Linux (the inverse direction) | — | — | binder, ashmem and namespaces are the reason "just use a container" does not transplant to a phone |
| WSL1 (lxcore) | syscall translation in a kernel-mode driver | — | yes | the same problem with full authority: no `ptrace` cost, because the translator owns the boundary. The engineering cost is a filesystem and a syscall surface, not a layer |
| [gVisor](https://gvisor.dev/) | a user-space kernel implementing the syscall surface | — | yes | the opposite extreme: complete, correct, and enormous; only worth it when you need isolation, not compatibility |
| box64, FEX, qemu-user, iSH | CPU translation / emulation | no | yes | a different axis entirely (M8). Composes with every method above, and changes the performance model rather than the platform model |
| bubblewrap and friends | user namespaces + `pivot_root` | no | yes | *if* the kernel allows `unshare -Ur`, M3 is the cheapest correct answer on the market; on most stock Android kernels it does not |
| Magisk, KernelSU | root | yes | yes | the honest shortcut: everything in this guide exists because that shortcut is unavailable |

## What they agree on

Across every implementation, the same three things are true:

1. **Somebody has to rewrite paths**, and the cheapest place is the one the
   program cannot bypass — the syscall boundary — which is also the most
   expensive per call. Every project's design is a position on that trade-off.
2. **Identity is fake.** None of them gives a real uid 0; they all lie
   convincingly, and the lies that fail are the ones a program can verify
   (`setuid` as a real syscall, `mount`, `chown` on the kernel's books).
3. **The tree is a directory.** No project mounts anything; every one of them
   has a page of documentation that amounts to "the tree is not your root, and
   tools that ask the kernel will get the phone's answer".

## What none of them solves

- **Real privilege.** `sudo` is theatre without a kernel uid change. Fine for
  `apt`; not fine for a daemon that drops privileges and checks.
- **`mount`, `tun`, `iptables`, kernel modules.** Root or nothing.
- **Systemd.** No PID 1 to hand out cgroups. Supervisors must be userspace
  (`runit` is the common choice because it needs nothing from the kernel).
- **The direction of the platform.** Apps targeting API 29+ cannot `execve`
  their data directory; 16 KB pages are arriving; a runtime that assumes
  `targetSdk 28` and 4 KB pages has a shelf life. The way forward is userland
  exec (M7) plus the runtime shipped as APK native libraries — that is the
  design the reference implementation is moving to, and it is not built yet [u].
- **GUI and GPU.** A terminal is a solved problem; a window is a device table, a
  compositor and a driver question. Nobody's path layer helps with it.

## If you are choosing today

- **A binary, not a tree** → a glibc bundle (M6).
- **A tree, and robustness beats speed** → proot (M2), through `proot-distro`.
- **A tree, and speed matters** → the hybrid (M5); budget for the three
  components and for keeping one owner of the path rule.
- **A product for other people's phones** → hybrid + userland exec, in an APK
  ([04](04-hosts.md#a-custom-apk)).
- **A lab device you own** → root and `chroot` (M1), and stop reading.
