# Deploy a script tree to a phone over adb

**Goal.** A tree of shell commands, built from a shared core plus one device pack,
deployed over adb, with the owner's configuration kept across deploys. No root.

**Recorded.** Sharp 701SH, Android 10, 2026-11-08 [m, recorded]: pages served, most
commands ran, the supervisor respawned; three assumptions about the host broke and
are [catalogued](../tree/bionic.md#what-broke-on-a-second-device). **Not re-run for
this repository.**

**Prerequisites.** `adb`; a static busybox on the host (it is not shipped, being
GPL-2.0); a tree directory with `bin/`, `lib/`, `etc/`; about 1 MB free.

**Time and size.** Minutes. The tree is a few hundred kilobytes.

**Steps.**

1. Build `core/` plus the device pack into one output directory (the pack overlays
   `etc/`: interfaces, command list, status blocks).

2. Deploy, keeping the owner's copies:

   ```sh
   deploy.sh <serial> --pack <device> --busybox /path/to/busybox
   ```

   The deploy pushes to `/data/local/tmp/<name>`, keeps `etc/*.conf` and ␣etc/*.list`,
   creates `bin/shims` as a symlink farm to the busybox, and sets the first-run
   files from their `.example` counterparts.

3. Start it and check the floor:

   ```sh
   adb shell '/data/local/tmp/<name>/bin/<name>-web start'
   check.sh <serial>
   ```

**Expected.** `check.sh` reports a served page, one status block with values, and one
command whose output is the phone's (not an error message).

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| every command says "not found" | the farm was not created, or `PATH` lacks `bin/shims` | `ls -l bin/shims/awk` |
| a status block is empty | the command behind it needs a capability the domain lacks | the block's command, run by hand |
| the owner's config was replaced | the deploy copied over `etc/*.conf` | keep `.example` files separate from the owner's copies |

**Undo.** `adb shell 'rm -rf /data/local/tmp/<name>'`; stop the supervisor first.

**Cost.** You write every command, and there is no package manager: a foreign
program is still foreign ([the host's own material](../tree/bionic.md)).
