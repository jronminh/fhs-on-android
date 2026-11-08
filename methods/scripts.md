# Scripts as commands

Isolation **0**. The tree's commands are files of POSIX `sh` that run on the host's
own `sh` and toybox; nothing is translated and nothing is foreign. This is how the
[host-material tree](../tree/bionic.md) is built, and it has the lowest cost of the methods here: no loader, no shim, no
tracer, no privilege.

## What it buys

- **Zero isolation**: the script is a process on Android like any other, so it can
  call the framework's own tools (`getprop`, `settings`, `svc`, `pm`, `am`, `dumpsys`)
  without a layer in between.
- **A tree that is readable and editable over ADB**, because every command is a
  file whose name is the verb.
- **A floor as old as Android 6**, because it needs nothing the ROM does not
  already ship.

## What it costs

- **You write every command**, and there is no package manager: version pinning
  and dependency resolution are manual.
- **Behaviour depends on the ROM** unless one busybox is pinned for POSIX tools
  ([tree/bionic.md](../tree/bionic.md)); toybox applets and options differ between
  AOSP versions, and `ip` is not a toybox applet at all.
- **A capability must be refused, not faked**: a command that needs root says so,
  exits with its own status, and keeps working without it.

## Example

[examples/cmd.sh](../examples/cmd.sh) is a command skeleton: the file name is the
command and the verbs are functions. The part that matters is that `check` answers
a question instead of printing:

```sh
VERBS="status check apply"
svc_check() {
    rc=0
    case "$(svc usb getFunctions 2>&1)" in
        *rndis*) : ;;
        *) echo "diff usb_functions: no rndis"; rc=1 ;;
    esac
    return "$rc"
}
```

Ran on the same three phones, 2026-11-08 [m]: `mode=shell`, `boot=1`, and
`functions=rndis` on the two with USB tethering on; the third printed an empty
line, which is exactly what `check` exists to catch.

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| a command works over ADB but not from the web | the caller's zone does not include that verb | read the command's zone (`view`/`act`/`any`) and the command table |
| `sh: <cmd>: not found` inside a script that works at the prompt | `bin/` is not first on `PATH` in that context | print `PATH` from the script; `bin/` must precede `/system/bin` |
| a script works on one phone and not another | a toybox applet or option that differs by AOSP version | run the same step through the pinned busybox, not the system tool |
| `print -r` works but `echo -e` does not (or the reverse) | the shell is `mksh`, not bash | keep scripts POSIX, test under `/system/bin/sh` |

## By domain

All three domains run scripts. In the **app** domain the script is a file in the
app's data directory, so the `execve` rule applies to it at `targetSdk` ≥ 29
([reference/domains.md](../reference/domains.md)).

## Evidence

The rules are stated as requirements a tree meets [s]; the busybox farm with its
applet list was built and used on a reference phone [m]; the shell is `mksh` on
Android [s]. [examples/cmd.sh](../examples/cmd.sh) is the shape both cases share.
