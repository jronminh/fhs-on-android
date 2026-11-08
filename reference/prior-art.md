# Prior art

Everything here has been done before, and along two different questions: *how to
run foreign binaries* and *how to keep a box alive*. Knowing which one a project
answered — and why — saves you from re-deriving its bug list.

| project | method | root | real FHS tree | teaches |
| --- | --- | --- | --- | --- |
| [proot](https://proot.gitlab.io/proot/) | `ptrace` path/identity translation | no | yes | proot is the most *portable* answer: it catches static binaries, raw syscalls and `execve` because it sits at the only boundary nothing can escape. Its cost is a stop per traced call, on every traced call. |
| [proot-distro](https://github.com/termux/proot-distro) | proot + a distro installer on Termux | no | yes | the ten-minute path to a working tree; also that the tree's own install scripts need patching for proot (`chown`, `useradd` in `debootstrap`) — evidence that assumption 4 (uid 0) is load-bearing, not cosmetic |
| [Termux](https://github.com/termux/termux-app) + termux-packages | native bionic packages, no tree | no | no | the platform runs fine when you stop fighting it: the least expensive "Linux on Android" is often *not* an FHS tree |
| [glibc-runner](https://github.com/termux-pacman/glibc-packages) and the Termux `glibc` bundles | a foreign glibc + patched loader beside Termux's prefix | no | no | a bundle is the right tool for a *binary* and the wrong tool for a *system*: no `dpkg`, no dependency graph, no `/usr/share` |
| Linux Deploy | root, `chroot` + loop image | yes | yes | `chroot` is the clean answer, and its popularity is why so many instructions silently assume root |
| Andronix, UserLAnd | proot/chroot + a UI and a store | no | yes | a runtime without packaging loses to one with an installer; the hard part for users is not the syscall layer |
| [Termux:X11](https://github.com/termux/termux-x11) | X11 server as an app, over a socket | no | yes | the display is a *device* problem with its own protocol; do not fold it into the path layer |
| Waydroid, Anbox | LXC/container running Android on Linux (the inverse direction) | — | — | binder, ashmem and namespaces are the reason "just use a container" does not transplant to a phone |
| WSL1 (lxcore) | syscall translation in a kernel-mode driver | — | yes | the same problem with full authority: no `ptrace` cost, because the translator owns the boundary. The engineering cost is a filesystem and a syscall surface, not a layer |
| [gVisor](https://gvisor.dev/) | a user-space kernel implementing the syscall surface | — | yes | the opposite extreme: complete, correct, and enormous; only worth it when you need isolation, not compatibility |
| box64, FEX, qemu-user, iSH | CPU translation / emulation | no | yes | a different axis entirely. Composes with every method above, and changes the performance model rather than the platform model |
| bubblewrap and friends | user namespaces + `pivot_root` | no | yes | *if* the kernel allows `unshare -Ur`, this is the least expensive correct answer; on most stock Android kernels it does not |
| Magisk, KernelSU | root + a patched boot image | yes | — | a shortcut with a stated cost, and the only durable mount point on the device: a factory reset clears `/data`, not `boot` — so a tree's **source** belongs there ([root](../tree/durability.md)) |
| OpenWrt, as a model rather than a port | procd/UCI/LuCI-shaped management over the device's own tools | no | no | the *management layer* is what makes a headless box usable — service verbs, a vetted command list, one password, a status block per file. Its components do not transplant (no PID 1, no absolute `/etc`, musl plugins); the **shape** does ([a bionic-native tree](../tree/bionic.md)) |
| a source-patched static binary (busybox, dropbear, curl) | build it yourself with the tree's paths compiled in | no | yes | the teach-the-binary technique in practice, and the only answer for static code: it cannot be trapped at run time, but it can be taught where it lives ([the four strategies](../tree/README.md#the-four-path-strategies)) |

## What they agree on

Across every implementation, the same three things are true:

1. **Somebody decides where a path points** — at run time (traced, interposed,
   rewritten), or at build time (taught, or avoided entirely by using the host's
   own material). Every project's design is a position on that axis and on its
   cost per call.
2. **Identity is constructed.** None of them gives a real uid 0; they present an
   identity the kernel does not confirm, and the answers that fail are the ones a
   program can verify (`setuid` as a real syscall, `mount`, `chown` on the
   kernel's books).
3. **The tree is a directory.** No project mounts anything; every one of them
   has a page of documentation that amounts to "the tree is not your root, and
   tools that ask the kernel will get the phone's answer".

## What every method leaves to someone else

- **Real privilege.** A `sudo` that answers from a shim is convincing and is not
  a kernel uid change. Enough for `apt`; not enough for a daemon that drops
  privileges and then checks.
- **`mount`, `tun`, `iptables`, kernel modules.** Root or nothing.
- **Systemd.** No PID 1 to hand out cgroups. Supervisors must be userspace
  (`runit` is the common choice because it needs nothing from the kernel).
- **The direction of the platform.** Apps targeting API 29+ cannot `execve`
  their data directory; 16 KB pages are arriving; a runtime that assumes
  `targetSdk 28` and 4 KB pages has a shelf life. The way forward is userland
  exec plus the runtime shipped as APK native libraries — a design that is
  described and not built here [u].
- **GUI and GPU.** A terminal is a solved problem; a window is a device table, a
  compositor and a driver question. Nobody's path layer helps with it.
- **Durability.** No tree survives a factory reset by being better at paths. It
  survives because someone put its *source* somewhere the reset does not reach
  ([root](../tree/durability.md#the-ladder)), and that is an operations decision,
  not a syscall one.
- **A broken framework.** The tree stays up; `svc`, `cmd` and `content` do not.
  Every project leaves you with two planes, and the rescue path has to live on
  the native one.

## If you are choosing today

- **A binary, not a tree** → a [glibc bundle](../methods/patch-package.md#a-bundle-not-a-tree).
- **A box that must survive anything** → [the host's own material](../tree/bionic.md) with its source
  in the boot image ([the host's own material](../tree/bionic.md), [durability](../tree/durability.md)).
- **A tree, and robustness beats speed** → [proot](../methods/tracer.md#proot-someone-elses-implementation), through `proot-distro`.
- **A tree, and speed matters** → a [hybrid](../methods/README.md); budget for the three
  components and for keeping one owner of the path rule.
- **A product for other people's phones** → hybrid + userland exec, in an APK
  ([hosts](./domains.md#the-app-domain)).
- **A lab device you own** → root and `chroot`, and stop reading.
