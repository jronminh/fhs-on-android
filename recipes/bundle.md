# A bundle: one program and its closure

**Goal.** One glibc program running on a phone with no tree, no `dpkg` and no
`chroot` — a directory you can `adb push` anywhere and run. **Isolation 1.**

**Basis.** **Recorded** — the project's bundle: a static busybox plus a glibc
program, its loader and three libraries, about 7 MB (the reference in
[the patch method](../methods/patch-package.md#a-bundle-not-a-tree)). Not re-run
for this repository; the phones have no `ldd` or `readelf` for the tree's glibc
[m] — `readelf` is absent on the 701SH — so the closure is taken on the host.

**Prerequisites.** an arm64 Debian userland on the host
([ingredients](ingredients-debian.md)), the program, `ldd` for its architecture.

**Time and size.** Minutes. About 7 MB for a busybox plus one program, most of
it the C library.

**Steps.**

1. Take the program's closure:

   ```sh
   ldd "$SRC/usr/bin/fastfetch" | awk '/=>/ {print $3} /^\// {print $1}'
   ```

2. Lay the bundle out with the loader, the libraries and the program under a
   `libexec/` that nothing patched:

   ```sh
   mkdir -p "$B/bin" "$B/lib" "$B/libexec"
   cp "$SRC/usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1" "$B/lib/"
   cp <the closure> "$B/lib/"
   cp "$SRC/usr/bin/fastfetch" "$B/libexec/"
   ```

3. Write one wrapper per program. It runs the bundle's loader *explicitly*, so
   the program's own `PT_INTERP` (a Debian path) never matters, and the bundle
   is relocatable:

   ```sh
   cat > "$B/bin/fastfetch" <<'EOS'
   #!/system/bin/sh
   b=${0%/*}/..
   exec "$b/lib/ld-linux-aarch64.so.1" --library-path "$b/lib" \
       "$b/libexec/fastfetch" "$@"
   EOS
   chmod 755 "$B/bin/fastfetch"
   ```

4. Add a static busybox for the shell tools, with its applet links relative:

   ```sh
   cp busybox "$B/bin/"; chmod 755 "$B/bin/busybox"
   ( cd "$B/bin" && ./busybox --list | while read -r a; do ln -sfn busybox "$a"; done )
   ```

5. Push it, and move it once to prove it is relocatable:

   ```sh
   adb push "$B" /data/local/tmp/bundle
   adb shell '/data/local/tmp/bundle/bin/fastfetch --version'
   adb shell 'mv /data/local/tmp/bundle /data/local/tmp/moved && /data/local/tmp/moved/bin/fastfetch --version'
   ```

**Expected.** Both invocations print the program's version, from either path —
the wrapper names the bundle's loader by a path relative to itself, so nothing is
baked. The bundle is one directory, and `du -sh` is a few megabytes.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `error while loading shared libraries` | the library is not in `lib/`, or the wrapper's `--library-path` is wrong | `ldd` the `libexec/` program on the host again |
| `version 'GLIBC_2.38' not found` | the loader and the libraries are from different builds | copy the closure from one userland, not two |
| running the program directly works but the wrapper fails | `$0` was a bare name (`fastfetch` from `PATH`) | call it by path, or resolve with `command -v` |
| an applet prints "not found" | the applet links are absolute | make them relative: `ln -sfn busybox sh` |

**Undo.**

```sh
adb shell 'rm -rf /data/local/tmp/bundle /data/local/tmp/moved'
```

**Cost.** A bundle is not a system: no dependency resolution, no `/usr/share`, no
package manager. When a program expects anything beyond its own closure, it is a
[tree](../tree/glibc.md), not a bundle.
