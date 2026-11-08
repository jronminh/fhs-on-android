# 5. Build a poor-host tree

A tree made out of the host's own material: Android's `sh`, toybox, one busybox,
and scripts. No `apt`, no foreign libc, no tracer — so nothing has to be
translated, and the tree can live where a foreign tree cannot.

This is not a toy recipe. On the reference devices it runs a device 24/7 as a
network uplink: web UI, services, ADB rescue path, OTA blocked, USB tether
re-applied at every boot, and the tree's source in the boot image so a factory
reset restores it ([6. Root](root.md)).

## Where does it live?

That choice is durability, not taste ([the ladder](root.md#the-durability-ladder)):

| place | survives a reboot | survives a factory reset | mode |
| --- | --- | --- | --- |
| `/data/local/tmp/<name>` | yes | no | rootless |
| `/data/adb/<name>` | yes | no | root (or `su`) |
| the boot image (`overlay.d`) | yes | **yes** | root |

Start rootless: it is the floor, it needs no unlock, and everything you write
must work there anyway ([hosts](hosts.md#adb-shell)). Move the source into the
boot image only when the tree is stable.

## Layout

```
TREE/                    e.g. /data/adb/net/userland, or /data/local/tmp/openar
├── bin/                 your commands: one script per verb set, plus busybox
│   └── shims/           symlink farm -> ../busybox (POSIX tools)
├── lib/                 shared shell libraries: platform, service, commands
├── etc/
│   ├── <name>.conf      owner intent: interfaces, port, thresholds
│   ├── httpd.conf       auth, mode 0600, outside the docroot
│   ├── commands.default the vetted command list
│   ├── status.d/        one file per status block
│   └── www/             page + cgi-bin/{view,act}
├── home/
├── tmp/
└── var/{log,run}/
```

Every entry point derives `TREE` **from its own location**, so the tree works
wherever it is copied and over `adb forward`:

```sh
TREE=${TREE:-$(cd "$(dirname "$0")/.." && pwd)}
```

This one line is why a tree can be moved from a PC to the phone and back without
editing anything.

## BusyBox first — the portability contract

Toybox applets and options differ between AOSP versions: `cmd` exists only from
Android 7.0, `ip` is not a toybox applet at all, `mktemp`/`top` come and go [s].
A tree that calls toybox directly is a tree that behaves differently on every
phone. So: **one busybox, and every POSIX tool comes through a symlink farm
created at deploy time.**

```sh
bin/busybox          # the operator's static busybox (GPL-2.0, not shipped here)
bin/shims/awk        # -> ../busybox
bin/shims/sed        # -> ../busybox
PATH=$TREE/bin/shims:$TREE/bin:/system/bin:/system/xbin
```

The proven set: `awk base64 cat cut date df dirname egrep fgrep find grep head ip
mktemp mkdir mv printf readlink realpath rm sed seq sha256sum sleep sort stat
tail tar timeout top touch tr uniq wc xargs gzip` [m].

Deliberately **not** shimmed, and each for a reason:

| tool | why the system's version, not busybox's |
| --- | --- |
| `ping` | busybox `ping` needs root; Android's does not |
| `sh` | `mksh` gives `print -r` and the platform's own quoting; the tree's scripts must run on it |
| `getprop settings svc pm am dumpsys logcat` | the framework's own interface — reimplementing it is how a tree rots |

`cmd` and private DNS are not used at all: they do not exist on the floor.

## Root is a mode, detected in one file

Nothing in the tree may assume root, and nothing may duplicate the check:

```sh
MODE=shell
[ "$(id -u 2>/dev/null)" = 0 ] && MODE=root
```

and the defaults follow from it [m]:

| | root | shell |
| --- | --- | --- |
| web port | 80 | 8080 |
| interfaces served | `usb0 swlan0` | `lo` (reach it with `adb forward`) |
| `/dev/kmsg` logging | written | skipped — `[ -w /dev/kmsg ]` first |
| boot durability | a boot hook | none: start it over ADB |

A feature that needs root says so, refuses fast (a distinct exit status), and
keeps working without it. That is the difference between a tree that runs
rootless and a tree that *pretends* to.

## Commands and services are files

A command is an entry in a tab-separated table, not code in a web page:

```
id  section  group(auto|view|act)  confirm  timeout_s  param_regex  description  command
```

A parameter is appended as one single-quoted word and must match `param_regex`;
output is capped (512 KB) and time-limited. Zones decide who may run what:
`view` (web GET) runs `auto`/`view`; `act` (web POST) runs `act` only; `any`
(ADB) runs everything.

A **service** is a script `bin/<name>` with a `VERBS="..."` line and one
`svc_<verb>` function per verb:

- `status` prints `key=value`;
- `check` exits 0 when the device is in line with intent, and prints `diff ...`
  otherwise;
- `apply` (and any act verbs) change state, and only through the act zone.

`check` is the important verb. "Is the tether up?" is a question about intent
versus the platform's state, and a tree that cannot answer it cannot heal itself.

## The web face

The UI is a view over the tree, never a second implementation:

- `busybox httpd`, **one instance per interface address**, never `0.0.0.0`
  (rootless default: loopback only);
- HTTP Basic, one password for the site, the password file outside the docroot
  and `0600`;
- pages are a frame plus blocks that load in parallel — a status block is a file
  in `etc/status.d/` whose first line is `# title: ...`;
- the only place that changes state is the **act zone**: POST only, `Host` must
  be one of the addresses the tree serves (blocks DNS rebinding), `Origin`/
  `Referer` must match (blocks CSRF), a second POST with `confirm=yes` executes,
  and every run appends one line to `var/log/actions.log`.

Rules that keep it honest:

1. no state that exists only in the UI — every control maps to a file in `etc/`
   or a command in `bin/`;
2. the rescue path is sacred: the package deny list refuses `android` and
   `com.android.shell`, because disabling either cuts ADB;
3. official framework mechanisms only (`svc`, `settings`, `cmd`, `pm`, `am`,
   `dumpsys`) — no `iptables`, no configfs, no sysfs archaeology;
4. the screen is not a dependency: every page works with the screen off and no
   launcher, keyboard or Settings app.

Rule 4 is measurable: the reference node was trimmed to ~24 packages, with no
launcher, SystemUI, telephony, Bluetooth or WebView, and the tree still answers
[m]. Blocks whose package was removed print `n/a`; commands fail with their own
message instead of pretending.

## Deploy

```
need a tree from two sources:  the shared core/ + one device pack
build    tools/build_tree.sh <device>       -> out/<device>/   (pack overlays core)
deploy   tools/deploy.sh <serial> --pack <device> [--root]
         push, keep owner config (etc/*.conf, etc/*.list), set first-run files
check    tools/check.sh <serial>            the floor: pages, one block, one command
```

Two rules from experience:

- **owner config is never overwritten** by a deploy: the tree ships
  `*.example`/`.default` files, and the owner's copies live beside them;
- **a device pack is data, not a fork**: per-device overlays of `etc/`
  (interfaces, command lists, status blocks), because the device-specific bits
  are what break between phones, not the tree.

## Keeping it alive

- **Supervisor**: a shell loop that respawns the web listener per interface.
  Borrow the instance policy that is proven in that role: restart threshold
  3600 s, retry 5, restart after 5 s.
- **Boot**: a `service.d` hook on a rooted device is one line calling a command
  in the tree — a hook, not a second implementation. For factory-reset
  durability, the source goes into the boot image instead ([6. Root](root.md)).
- **Early calls**: after a reboot, ADB answers at ~27–30 s, the package manager
  at ~31–33 s, `sys.boot_completed` at ~35–38 s [m]. A tree that runs at boot
  must tolerate the framework not being ready yet, and must be idempotent when
  it runs a second time.
- **Health**: one script that prints the things you would check by hand (mode,
  addresses, listeners, last log lines, crash hints) — the first command in any
  session.

## What it costs, and what broke

Costs: every command is yours to write; foreign binaries still need
[strategy 1–3](two-kinds-of-tree.md#the-four-path-strategies); there is no
dependency resolution, so version pinning is manual.

Three failures from taking this to a *rootless* second device (Android 10,
kernel 4.4) [m], each a general lesson:

| symptom | cause | lesson |
| --- | --- | --- |
| every path wrong on the new device | the tree's root was hardcoded (`T=...`) | derive the root from `$0`; a tree that names its own path is not portable |
| a config file resolved to the wrong place | it was assumed to live in the boot ramdisk, which only exists on a rooted device | no path may assume the boot image; check for it, and fail loudly when it is missing |
| `echo > /dev/kmsg` printed a hard error | the log helper wrote unconditionally; rootless has no writable kmsg | guard the sink: `[ -w /dev/kmsg ] &&`, and always keep the file log |

None of the three was a design failure; all three were *assumptions about the
host* leaking into the tree. That is the characteristic bug class of this kind
of tree, and the fix is always the same: one file that answers "where am I and
what may I do", and no other file allowed to guess.

## When not to build one

- You need `apt`, a compiler or unmodified software → a [foreign tree](foreign-tree.md).
- You need one foreign binary → a loader bundle, not a tree.
- You do not control the device's boot → skip the durability work and run it
  over ADB, but say so in the README instead of implying persistence.
