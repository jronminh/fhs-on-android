# An entry script a launcher can call

**Goal.** The tree's `boot/boot.sh`: it finds its root from its own path, drops
the host's loader knobs, enters the tree, and runs a command under a clean
environment — the shape a launcher (a PC, an app, a master) calls. **Isolation
unchanged**: the script is the host's environment rule made concrete, not a
layer inside the program.

**Basis.** **Run here**, 2026-11-08, in the shell domain on both phones (S10e,
Android 12, kernel 4.14.190; Sharp 701SH, Android 10, kernel 4.4.205): `uid=2000`,
`Seccomp: 0`. The runtime call in step 3 is recorded from the project, not run
here.

**Prerequisites.** `adb` and a writable directory (`/data/local/tmp`); nothing
else — the script runs on the phone's own `sh`.

**Time and size.** A second. A few hundred bytes.

**Steps.**

1. Write the entry, next to the tree it starts:

   ```sh
   mkdir -p "$T/boot"
   cat > "$T/boot/boot.sh" <<'EOS'
   #!/system/bin/sh
   root=$(CDPATH= cd -P -- "${0%/*}/.." && pwd -P) || exit 1
   unset LD_PRELOAD LD_LIBRARY_PATH
   cd "$root" || exit 1
   umask 022
   tz=$(getprop persist.sys.timezone 2>/dev/null)
   exec env -i PATH=/system/bin:/usr/bin HOME="$root" TMPDIR="$root" \
       TERM="${TERM:-dumb}" TZ="${tz:-UTC}" /system/bin/sh "$@"
   EOS
   chmod 755 "$T/boot/boot.sh"
   ```

2. Call it from anywhere, with a command:

   ```sh
   "$T/boot/boot.sh" -c 'echo "entry: ok"; echo "uid: $(id -u)"; echo "cwd: $(pwd)"; echo "kernel: $(uname -r)"'
   ```

3. A real tree replaces the last line with its runtime, and the tree's own
   `boot/init.sh` as the command:

   ```sh
   exec env -i ... "$root/usr/lib/deb-native/dn-init" -q -s 500 \
       -t "$root" -- /usr/bin/bash /boot/init.sh "$@"
   ```

**Expected.** With `$T=/data/local/tmp/foa-entry`, on both phones [m]:

```
entry: ok
uid: 2000
cwd: /data/local/tmp/foa-entry
kernel: 4.14.190-23725627-abG970WVLU9IXE1      (S10e, Android 12)
kernel: 4.4.205-perf                            (701SH, Android 10)
home: /data/local/tmp/foa-entry
path: /system/bin:/usr/bin
rc=0
```

The `uid` is the phone's (`shell`), the `cwd` and `HOME` are the tree's, and the
`PATH` is the script's alone — the three things the entry exists to get right.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `cd: no such directory` | `$0` was a bare name, so `${0%/*}` is `.` | call it by path, or resolve with `command -v` first |
| `cwd: /` or the host's directory | `cd` skipped, or run with `sh -c` so `$0` is `sh` | `echo "$0"` from the script |
| every program in the tree aborts at start | an inherited `LD_PRELOAD` reached a glibc loader that cannot use it | `unset LD_PRELOAD` before the `exec`, as step 1 does |
| `pwd` shows the tree's real path but a program's `getcwd` shows another | the tree is reached through a symlink | resolve with `pwd -P`, as step 1 does |

**Undo.**

```sh
rm -rf "$T"
```

**Cost.** None to the program — but the script owns `PATH`, `HOME` and `TMPDIR`
for everything it starts, so a second entry script is a second environment rule.
Keep one per tree, and let the launcher pass variables through it (the project's
`boot/env` file) rather than around it.
