# The device nodes a tree sees

`/dev` is the phone's. A tree does not carry device nodes of its own — a tree at
level 4 mounts or copies the phone's — and what a program may open is decided by
the **domain's permissions** and by the vendor's kernel, not by the tree.

The rule that follows: **a node the domain may not open is not a tree problem.**
It is root, or a host service. No path rule, shim or tracer creates a device.

## What is there

| nodes | what a tree gets |
| --- | --- |
| `/dev/null`, `zero`, `full`, `random`, `urandom` | the kernel's own; pass-through, nothing to model [s] |
| `/dev/tty`, `/dev/ptmx`, `/dev/pts/*` | the process's controlling terminal, and the host's PTYs if the domain may open them; whether it may is a probe per release [u] ([mechanisms](mechanisms.md#a-terminal)) |
| `/dev/console` | there is no VT layer on Android, so a console is a PTY the host owns or `ENODEV` — never a socket dressed as a terminal [s] |
| `/dev/tty0..N` | refused: there is no VT to back them [s] |
| `/dev/kmsg` | **root only**; rootless, the shell reports a hard error on the redirect before the syscall, so a tree's log has to be a file [m] |
| `/dev/net/tun` | absent for the app and the shell domains; a VPN is the framework's (`VpnService`), and the routing is the app's, not the tree's [m] |
| `/dev/fuse`, `/dev/loop*` | not for an app; the kernel's FUSE and loop devices are the platform's [s] |
| the GPU | the vendor's interface (`/dev/kgsl-3d0`, `/dev/mali*`), not a DRM card: a phone's display is the framework's, and there is no KMS device for a tree to drive [s] |
| audio | no `/dev/snd` to open: audio is a host service (the framework's mixer), not a device [s] |
| `/dev/input/*`, `/dev/video*` | the framework owns input and the codecs; whether a domain may open the node is a probe, and a host service is the way in, not the tree [u] |

## What it means for a tree

- **A missing node has two answers**: root (which a stock phone does not give,
  [the isolation scale](../README.md#the-isolation-scale)) or a host service
  that grants the capability — a VPN app that owns the tunnel, a compositor, a
  mixer. The tree is the wrong place for either.
- **A broker that fakes a node is a runtime's feature**, not the tree's: it needs
  a stateful fd, `ioctl`, `mmap`, `poll` and `stat` that agree, which is a device
  ABI under the path rule, not a path [s]. The runtime's own device work is a
  proposal; this guide does not ship it.
- **A level-4 tree with its own `/dev`** gets the nodes it copied, and loses the
  rest: that is the reach the `chroot` costs ([chroot](../methods/chroot.md)).
- **A tree with no layer at all** sees the phone's `/dev` exactly as the domain
  does, which is the same answer for this one surface as a traced tree's.

## Getting your device's numbers

[examples/probe.sh](../examples/probe.sh) tests `null`, `zero`, `urandom`, `tty`,
`tun` and `fuse`, and reports the GPU nodes it finds. A node this page names but
the probe does not test needs one `test -r` — and the answer is per domain.

## Evidence

- **[m]** the `/dev/kmsg` row (rootless, 2026-11-08) and the absence of
  `/dev/net/tun` for an app, both on named devices.
- **[s]** the platform's design for the console, VT, DRM, audio and FUSE.
- **[u]** the per-domain openability of PTYs, evdev and the media nodes: a probe
  per release, not a fact this guide has measured for you.
