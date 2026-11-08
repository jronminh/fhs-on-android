# 3. Build a tree

Two recipes. The first gets a working tree in ten minutes and accepts a
performance cost; the second gets a native-speed tree and expects you to
understand [02](02-methods.md).

Both start from the same place: an `arm64` phone with
[Termux](https://github.com/termux/termux-app) installed from F-Droid or GitHub
(the Play build is not the same app and cannot install packages).

## Experiment first: three failures in five minutes

Before choosing a method, watch the platform fail. This is the fastest way to
internalise why the layer exists.

```sh
mkdir -p ~/tree && cd ~/tree
# 1. a static binary: works at once, and it sees the *phone's* root, not yours
pkg install busybox
cp $(command -v busybox) ./busybox && chmod +x ./busybox
./busybox ls /            # the phone's /
```

```sh
# 2. a dynamic Debian binary from a real tree: this is the classic surprise
./tree/usr/bin/dpkg --version
#   sh: ./tree/usr/bin/dpkg: No such file or directory
# The file is there. What is missing is the *interpreter* named in its ELF header.
readelf -l ./tree/usr/bin/dpkg | grep interpreter
#   [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
# /lib does not exist at the phone's root. The kernel resolved it there, not in your tree.
```

```sh
# 3. point the interpreter at the tree, by absolute path
patchelf --set-interpreter /data/data/com.termux/files/home/tree/lib/ld-linux-aarch64.so.1 \
  ./tree/usr/bin/dpkg
./tree/usr/bin/dpkg --version          # usually works
```

Three lessons, all structural:

- a **static** binary needs no loader, so it runs immediately — and then reads
  the *phone's* filesystem, because nothing translates its paths;
- a **dynamic** binary fails before `main`, with an error that names no missing
  library, because the kernel resolves `PT_INTERP` against the real root;
- rewriting the interpreter fixes the entry point and nothing else. The path is
  now **baked**: move the tree and it breaks. That is why a relocatable loader
  derives its prefix from its own location instead.

[Source: ELF and `ld.so` semantics, plus the relocation work in [07](07-prior-art.md).
The exact error strings vary by shell and Android version.]

## Recipe A — proot-distro, ten minutes

```sh
pkg install proot-distro
proot-distro install debian
proot-distro login debian
```

Inside: `apt update`, `apt install build-essential`. You now have a complete
Debian `arm64` tree at `$PREFIX/var/lib/proot-distro/installed-rootfs/debian`,
root in the tree, `apt` unmodified, no root on the phone.

- **What you got:** method M2. The tree is real; the cost is a `ptrace` stop per
  traced syscall, paid on every metadata-heavy operation.
- **What you did not get:** near-native speed, and any control over the path
  rule — proot's implementation is the one you have.
- **Where it breaks:** CPU-bound work is fine; `apt`, `find`, `git status` and
  large `configure` runs are where you will feel it. Measure before deciding it
  is too slow ([06](06-measure.md)).

## Recipe B — a native tree

### B.0 What you are building

```
TREE/
├── boot/                     <- the entry points (names vary by implementation)
│   └── boot.sh               <- run this, from anywhere
├── usr/lib/<runtime>/        <- the runtime artifacts (loader shim, tracer, exec)
├── etc/passwd, group, shadow <- at least the uid the tree runs as
├── var/lib/<runtime>/        <- generated state (link generations, caches)
└── ... a Debian tree
```

An ordinary Debian tree plus (a) a runtime, (b) an entry point, (c) a directory
for generated state. Nothing else distinguishes it.

### B.1 Put a Debian `arm64` tree in a directory

Three ways, all equivalent:

```sh
# a) on the phone, in Termux
pkg install debootstrap
debootstrap --foreign --arch=arm64 --variant=minbase trixie ~/tree http://deb.debian.org/debian

# b) on a PC, then copy the tar over
mmdebstrap --arch=arm64 --variant=minbase trixie tree.tar \
  http://deb.debian.org/debian
# (mmdebstrap wants qemu-user-static or a foreign bootstrap; it does not run the
#  second stage if you ask it for a tarball, which is what you want here)

# c) any Debian rootfs tarball for arm64, unpacked into ~/tree
```

**Termux gotcha.** Termux's `debootstrap` patches out `chown`, `useradd` and
friends in its second stage, because it is written for proot. Left in place,
those lines empty the helpers and your first `apt install` breaks in a way that
looks like a permission bug. Drop them:

```sh
sed -i '/^[[:space:]]*echo "" > "\$TARGET\//d' ~/tree/debootstrap/debian-common
```

### B.2 Decide who resolves the paths

That is [02](02-methods.md). For recipe B the answer is the hybrid (M5): static
rewrite for the entry point, a shim for the dynamic calls, a tracer for the rest.
The reference implementation of that method is
[deb-native](https://github.com/jronminh/deb-native):

```sh
pkg install git clang python
git clone https://github.com/jronminh/deb-native && cd deb-native

scripts/runtime/build-runtime.sh          # the tracer and the userland exec
scripts/runtime/build-shim.sh --cross     # the preloadable DSO
scripts/prefix/build-prefix.sh ~/tree     # the tree itself
```

What `build-prefix.sh` does, in order — and this order is the important part:

1. `debootstrap --foreign`: fetch the base packages, unpack them;
2. put the runtime in the tree (`usr/lib/deb-native/`, `boot/`);
3. run `debootstrap --second-stage` **under the runtime**, so every maintainer
   script executes as it would on Debian, as (fake) root;
4. write apt sources, `apt-get update`, install the packages you asked for;
5. `apt-get clean`, write `boot/version`.

Step 3 is the bar-2 test. If it passes, `apt` will work for the life of the
tree; if it fails, the log at `TREE/debootstrap/debootstrap.log` has the
package and the script's output.

On the reference device (S10e, Android 12): ~3 minutes, 265 MB for the minimal
set, 811 MB for the development set, most of it download. [m]

### B.3 By hand, without the wrapper

The script is a convenience. This is all it relies on:

```sh
DEST=~/tree
debootstrap --foreign --arch=arm64 --variant=minbase trixie "$DEST" http://deb.debian.org/debian
sed -i '/^[[:space:]]*echo "" > "\$TARGET\//d' "$DEST/debootstrap/debian-common"

mkdir -p "$DEST/usr/lib/deb-native" "$DEST/boot"
cp build/dn-init build/dn-exec build/dn-lane.so "$DEST/usr/lib/deb-native/"
cp scripts/prefix/boot.sh scripts/prefix/init.sh "$DEST/boot/"

env -i HOME=/root PATH=/usr/sbin:/usr/bin:/sbin:/bin \
  "$DEST/usr/lib/deb-native/dn-init" -t "$(cd "$DEST" && pwd)" \
  -- /bin/sh /debootstrap/debootstrap --second-stage
```

`env -i` matters: the tree's second stage must not inherit Termux's `PATH`,
`LD_PRELOAD` or `TMPDIR`. A surprising share of "the build fails only on my
phone" reports are an inherited variable.

### B.4 Boot it and check the three bars

```sh
~/tree/boot/boot.sh                    # interactive shell, root in the tree
```

| bar | command | expected |
| --- | --- | --- |
| 1 | `id` | `uid=0(root)` (fake, in-tree) |
| 1 | `ls -l /usr/lib \| head` | real Debian libraries, not `/system` |
| 1 | `dpkg -l \| head` | a package list |
| 2 | `apt-get update && apt-get install figlet` | downloads, unpacks, runs `postinst`, `figlet` works |
| 3 | `git init /tmp/x && cd /tmp/x && git status` | no crash, no `ENOENT` |
| 3 | `python3 -c 'import os; print(sum(1 for r,d,f in os.walk("/usr") for _ in f))'` | a number, in seconds |
| 3 | build something: `apt install build-essential && tar xf lua-5.4.7.tar.gz && cd lua-5.4.7 && make -j1` | completes |

`figlet` is the canonical bar-2 canary: its `postinst` runs binaries, writes
`/usr/share`, and touches `/usr/share/figlet`. If `figlet` installs, the
relocation is healthy.

### B.5 Move the tree

A tree must not bake its own path. Two things follow:

- the entry point finds the tree from **its own location**, not from a compile-
  time constant;
- an unprivileged `tar` drops setuid bits, so the tree records which files were
  setuid at build time and restores them at boot. This is what keeps `sudo`,
  `su` and `passwd` working after a copy or an `adb push`.

```sh
tar -C ~ -czf /sdcard/tree.tar.gz tree      # in Termux
tar -C SOMEWHERE -xzf /sdcard/tree.tar.gz   # as the user who will own it
```

If your tree needs `patchelf`-style absolute interpreters, it is not relocatable
and this step will break it. That is a design decision made in B.2, not a bug to
work around later.

## Updating the runtime without rebuilding the tree

The runtime is small and the tree is large, so keep them separable:

```sh
scripts/runtime/build-runtime.sh
scripts/runtime/build-shim.sh --in-prefix ~/tree   # or --cross
cp build/dn-init build/dn-exec build/dn-lane.so ~/tree/usr/lib/deb-native/
cp scripts/prefix/boot.sh scripts/prefix/init.sh ~/tree/boot/
```

Nothing has to be compiled *inside* the tree: the shim is linked against a glibc
of your choosing, and `--in-prefix` simply picks the tree's own so the ABI floor
matches. Record which libc a shim was built against; a shim built on a newer
glibc than the tree carries will fail to load with a version error.

## When bar 2 fails

In order, and stop at the first one that applies:

1. **`debootstrap.log`** — the package and the maintainer script's output. Read
   the *last* failure, not the first; scripts cascade.
2. **Turn the shim off** — move the shim aside, or set the implementation's
   "no-patch" variable. If the failure disappears, it is a shim bug, not a tree
   bug.
3. **Run without the userland exec** — many runtimes have a flag that falls back
   to the plain loader path. If behaviour differs, the birth-time patching is at
   fault.
4. **Drop `-q`** on the tracer to get the stop counts by kind
   ([06](06-measure.md) explains what they mean), and verbose output on the
   first failure only.
5. Then [05](05-limits.md) — the failure catalogue, by symptom.
