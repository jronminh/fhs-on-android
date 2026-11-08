# TODO - what is measured, what is next

Two rules for this file:

1. **Done means a run.** An item moves here only with a device, an Android
   version, a date and an output that is in this repository - a page, a row in
   [evidence](reference/evidence.md), or a line in [examples](reference/examples.md).
2. **This file does not restate claims.** It points at the page that owns the
   claim, so there is one owner for every fact.

## Done, measured

| what | where the output lives |
| --- | --- |
| `which-loader` on Android 12 and 15: `interp: /system/bin/linker64`; Android 10 has no `readelf`, so it exits 69 instead of guessing "static" | [examples](reference/examples.md) |
| the shell domain refuses `chroot` (125) and `unshare -Ur` (1) on Android 10, 12 and 15 | [chroot](methods/chroot.md) |
| root: `uid=0`, `chroot` **ok**, `unshare -Ur` **still refused**, `/dev/kmsg` writable, boot partition 64 MB | [root](tree/root.md) |
| level 4 with a busybox tree: 1.7 MB, 359 applets, `/system` absent inside | [root](tree/root.md) |
| level 4 with a glibc tree: 2.1 MB, `Debian GLIBC 2.41` reported from inside, `dash` runs | [chroot](methods/chroot.md) |
| the three loader states: no loader `ENOENT`, loader at 0644 `EACCES`, 0755 runs | [chroot](methods/chroot.md#the-two-loader-states-that-come-first) |
| a path shim maps a name but a static binary still sees the host; a symbol-level identity answers `getuid` but not `fchownat` | [examples](reference/examples.md) |
| a rootless tree of commands (72 KB), a busybox chroot (1.7 MB) and a glibc chroot (2.1 MB), each as a recipe with an undo | [recipes](recipes/README.md) |
| a Debian arm64 userland on a host: 64 s and 225 MB with `debootstrap --foreign` | [recipes/ingredients-debian.md](recipes/ingredients-debian.md) |

## Next, in suggested order

### 1. A full glibc tree under `chroot`

The 2.1 MB tree proves the loader and libc work. It does not prove a *package*
manager works at level 4. Take a real glibc userland (a few hundred MB), bind
`proc`/`sys`/`dev`, chroot, and run `apt-get update && apt-get install figlet`.

- **settles:** the package-manager check at level 4;
- **needs:** a rooted phone, ~400 MB free, one session;
- **output:** the last lines of `apt-get`, and a row in [evidence](reference/evidence.md).

### 2. Own the libc

Build glibc from source on a Linux host (the LFS bootstrap), then run it under
`chroot` on the phone. Record what breaks: the loader path the programs name, the
cache, locales.

- **settles:** the `[u]` in [own-libc](methods/own-libc.md) - the branch is valid but unbuilt here;
- **needs:** hours on a host, no phone root;
- **output:** a build transcript reduced to the failure signatures, plus one run.

### 3. Two CI checks

A single workflow, no device: (a) every internal link and anchor resolves;
(b) every file in `examples/` passes `sh -n`, and the two C files pass
`gcc -fsyntax-only`.

- **settles:** drift - a rename that breaks a link, a script that stops parsing;
- **needs:** nothing but a workflow file.

### 4. User namespaces, on more devices

`unshare -Ur true` is refused on the three phones here, including as root. Probe
more kernels and ROMs before writing level 4 without root off entirely.

- **settles:** whether the rootless half of level 4 exists anywhere;
- **output:** one row per device in [evidence](reference/evidence.md).

### 5. A virtual machine (level 5)

AVF on a supported device, with a tree inside it: what it can reach, what it
cannot, and what the tree costs in there.

- **settles:** the last row of the isolation scale;
- **needs:** a device with AVF and a lot of patience.

### 6. Re-run the multi-distro case

A second glibc supply (an Ubuntu or Arch tree) under the same core, so the claim
that the loader comes from the program is reproducible from this repository.

- **settles:** "any glibc userland" as an in-repo measurement, not a memory.

## Deliberately not on this list

- **musl.** Out of scope, with its reason in [the problem](reference/problem.md); it
  reopens only with a measurement attached.
- **Isolation** as a goal. The tree exists to use Android; isolation is the cost,
  not the product.

## How to close an item

Run it, write the output where the claim lives, add the row to
[evidence](reference/evidence.md), move the item to **Done, measured**, and
delete the section. An item without an output is not done.
