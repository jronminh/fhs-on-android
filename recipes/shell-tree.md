# A tree of commands, no root

**Goal.** A directory that behaves like a small command set: one file per
command, first on `PATH`, on an unrooted phone, with nothing downloaded.
**Isolation 0**: the commands are scripts on the phone's own shell.

**Tested on.** Galaxy S10e, Android 12 (sdk 31), kernel 4.14.190, 2026-11-08
[m].

**Prerequisites.**

- `adb` and a phone that allows it; no root, no busybox, no network;
- a writable directory you own: `/data/local/tmp` or the app's data.

**Time and size.** Under a minute. The tree with two commands is 72 KB.

**Steps.**

1. Make the layout:

   ```sh
   T=/data/local/tmp/fhs-tree
   mkdir -p "$T/bin" "$T/etc" "$T/var/log" "$T/tmp"
   ```

2. Write one command. The file name is the command name:

   ```sh
   cat > "$T/bin/hello" <<'EOF'
   #!/system/bin/sh
   echo "hello from $(dirname "$0")"
   echo "kernel $(uname -r)"
   EOF
   chmod 755 "$T/bin/hello"
   ```

3. Write one that answers a question about the phone:

   ```sh
   cat > "$T/bin/status" <<'EOF'
   #!/system/bin/sh
   printf "mode=%s\n" "$( [ "$(id -u)" = 0 ] && echo root || echo shell )"
   printf "sdk=%s\n" "$(getprop ro.build.version.sdk)"
   printf "seccomp=%s\n" "$(sed -n "s/^Seccomp:[[:space:]]*//p" /proc/self/status)"
   EOF
   chmod 755 "$T/bin/status"
   ```

4. Put `bin` first and call them by name:

   ```sh
   PATH="$T/bin:/system/bin" hello
   PATH="$T/bin:/system/bin" status
   ```

**Expected.**

```
hello from /data/local/tmp/fhs-tree/bin
kernel 4.14.190-23725627-abG970WVLU9IXE1
mode=shell
sdk=31
seccomp=0
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `hello: not found` | `bin` is not first on `PATH` | echo `$PATH` before calling |
| `Permission denied` | the file is not executable | `chmod 755` |
| works over ADB, not from an app | the app domain refuses `execve` of app data at `targetSdk` 29 and above | run it from the shell domain, or see [exec](../methods/exec.md) |

**Undo.**

```sh
rm -rf /data/local/tmp/fhs-tree
```

**Cost.** You write every command. toybox applets and options differ between
AOSP versions, so a command that uses one behaves differently per phone
([the host's own material](../tree/bionic.md)).
