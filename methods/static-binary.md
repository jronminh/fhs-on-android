# A static binary

Isolation **0**. A static binary brings its own everything: no loader, no
`ld.so.cache`, no libc in the tree. The tree only has to let it run — and to be
honest that it sees the **phone's** filesystem, not a tree's.

## What it buys

- **The cheapest way to add a real program**: copy it in, make it executable,
  done. Native speed, no layer, no privilege.
- **It cannot be broken by a tree change** — there is no path to bake and no
  library to resolve.
- **It is the floor of the host-material tree**, which on a stock phone runs
  static binaries only (a dynamic bionic program needs the app's own library
  path; a dynamic glibc program needs the whole [glibc supply](../tree/glibc.md)).

## What it costs

- **Its paths are Android's**: nothing at run time can tell a static binary where
  the tree is, so a program that writes `/etc` writes Android's `/etc` if it may,
  and one that reads `/usr/share` finds nothing.
- **No shared fixes**: a CVE in its libraries is a rebuild, not a package update.
- **Size**, repeated per program, and no deduplication.

## Example

[examples/which-loader.sh](../examples/which-loader.sh) separates the two cases a
static binary introduces: no interpreter at all, or an interpreter that does not
exist under the tree.

```sh
interp=$(readelf -l "$prog" | sed -n 's/.*program interpreter: \(.*\)]/\1/p')
[ -z "$interp" ] && { echo "static: no interpreter, nothing to resolve"; exit 0; }
[ -e "$tree$interp" ] || echo "MISSING: $tree$interp (execve answers ENOENT)"
```

Ran on three phones, 2026-11-08 [m]: on Android 12 and 15 it prints
`interp: /system/bin/linker64` and `resolves:`; pointed at a directory that is not a
tree, the same line becomes `MISSING:` - exactly the `ENOENT` a real exec returns. On
Android 10 (sdk 29) there is no `readelf`, and the script exits 69 instead of guessing
"static".

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| `ldd ./program` says "not a dynamic executable" | it is static; the loader is not the problem | paths or the kernel — go to [limits](../reference/limits.md) |
| `Exec format error` on a binary that runs elsewhere | wrong architecture (an `amd64` or `armhf` tarball) | `readelf -h`; `uname -m` says `aarch64` |
| it runs and reads the phone's `/etc` | nothing translates a static binary | [rebuild](rebuild.md) it with the tree's paths |
| `Text file busy` while replacing it | the file is being executed from this inode | write a temp name and `rename(2)` |

## By domain

In the **app** domain, `execve` of app data is refused at `targetSdk` ≥ 29, which is
what [exec](exec.md) exists to work around. In **shell** and **root** it runs
directly.

## Evidence

A static `busybox` is the base of a host-material tree [m]; the host-only
environment runs static binaries only, by construction [s]; a static `dropbear`
ran only after it was taught its paths ([rebuild](rebuild.md)) [m].

