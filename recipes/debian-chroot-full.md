# A full Debian tree under chroot, with a package manager

**Goal.** A configured Debian `arm64` tree in a chroot on a rooted phone: the base
packages installed, `apt` working, one package installed and run.
**Isolation 4.**

**Tested on.** Galaxy S21 FE, Android 15 (sdk 35), kernel 5.4.242, Magisk root,
2026-11-08 [m].

**Prerequisites.**

- root, about 300 MB free in `/data`;
- the userland from [ingredients-debian](ingredients-debian.md): `debootstrap
  --foreign` took 57 s and produced a 93.7 MB tarball;
- network on the phone for `apt` (the tree's `/etc/resolv.conf` is written by
  hand).

**Time and size.** About ten minutes. 225 MB unpacked, 78 base packages.

**Steps.**

1. Push the tarball and extract it as root:

   ```sh
   adb push trixie.tar.gz /data/local/tmp/
   adb shell 'su -c "mkdir -p /data/adb && tar xzf /data/local/tmp/trixie.tar.gz -C /data/adb"'
   ```

2. Bind the kernel filesystems and write a resolver:

   ```sh
   T=/data/adb/trixie-arm64
   mount -t proc proc "$T/proc"; mount -t sysfs sysfs "$T/sys"; mount -o bind /dev "$T/dev"
   printf 'nameserver 1.1.1.1\n' > "$T/etc/resolv.conf"
   ```

3. The tree arrives **extracted, not installed**: install the base packages from
   the tarball's own cache:

   ```sh
   chroot "$T" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TMPDIR=/tmp \
     /bin/sh -c 'cd /var/cache/apt/archives && dpkg -i --force-depends *.deb'
   ```

4. Configure them with a **clean environment**:

   ```sh
   chroot "$T" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TMPDIR=/tmp \
     DEBIAN_FRONTEND=noninteractive /bin/sh -c 'dpkg --configure -a'
   ```

5. Use the package manager:

   ```sh
   chroot "$T" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TMPDIR=/tmp \
     DEBIAN_FRONTEND=noninteractive /bin/sh -c 'apt-get update && apt-get install -y figlet'
   chroot "$T" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TMPDIR=/tmp \
     /bin/sh -c 'figlet fhs'
   ```

**Expected.**

```
Setting up base-passwd (3.6.7) ...
configure_rc=0
78
Unpacking figlet (2.2.5-3+b2) ...
Setting up figlet (2.2.5-3+b2) ...
  __ _
 / _| |__  ___
| |_| '_ \/ __|
|  _| | | \__ \
|_| |_| |_|___/
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `grep: not found`, `dpkg: not found` inside the chroot | the shell inherited Android's `PATH` | pass `PATH` explicitly, or use `env -i` |
| `mktemp: failed to create file via template '/data/local/tmp/tmp.XXXXXX'` | `TMPDIR` from Android points outside the tree | `env -i` with `TMPDIR=/tmp` |
| `E: No pkgdetails available` | `debootstrap --second-stage` is not usable here | install the cached `.deb`s with `dpkg` instead |
| `apt` warns `No sandbox user '_apt'` | the base tree has no sandbox user yet | harmless for a first install [m] |
| `Device or resource busy` when removing the tree | the `/dev` bind is still mounted, with its submounts | `umount -l` the bind, then `rm -rf` |

**Undo.**

```sh
umount -l /data/adb/trixie-arm64/dev; umount /data/adb/trixie-arm64/sys; umount /data/adb/trixie-arm64/proc
rm -rf /data/adb/trixie-arm64 /data/local/tmp/trixie.tar.gz
```

**Cost.** Level 4: inside, Android's `/system`, `/data` and services are out of
reach, and the tree occupies 225 MB. The package manager works because the tree is
a distribution in its own right — which is more than "a place for a program"
([the glibc supply](../tree/glibc.md)).
