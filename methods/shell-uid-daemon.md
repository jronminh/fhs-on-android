# A shell-UID daemon

Isolation **0** for the command path. One authorized ADB launch starts a
long-lived daemon in the shell domain (UID 2000) [s]. An app-domain client
requests commands, which the daemon runs under its own credentials [s].

## What it buys

- The app keeps its UID while commands use the shell domain's access [s].
- Once detached, the daemon can accept commands over its own connection after
  the launching `adb shell` returns or its connection drops [s].
- A phone can start the daemon without a PC by acting as its own ADB client [s].

## What it costs

- The daemon must authenticate the client before accepting a command. Loopback
  limits the network path but does not establish the caller's identity [s].
- Commands use the shell domain's view of the phone and its access limits [s].
- The operator needs an authorized launch path again when the daemon dies [s].

### Detaching from adb

The first fork lets the launching process exit and gives its child a PID
different from its inherited process group ID, so it can call `setsid()` [s].
`setsid()` creates a session and process group with no controlling terminal,
leaving the original terminal's hangup and process group behind [s]. The second
fork lets the session leader exit and leaves a grandchild that cannot acquire a
controlling terminal just by opening a terminal device [s].

Redirect stdin, stdout and stderr away from the launching pipes or PTY and close
other inherited ADB descriptors so they cannot keep the connection open [s].
`chdir("/")` releases the inherited working directory's mount reference [s].
On shell-protocol disconnect, AOSP `adbd` can send `SIGHUP` to the shell
subprocess it tracks [s]. Signals to the original POSIX group miss the new
group [s]. Android init can still clean up the `adbd` service cgroup [s].

### Pairing from the phone

Wireless debugging supports code pairing from Android 11 [s]. The user gets
the code in Developer options and enters it in the helper's inline notification
reply [s]. The client discovers `_adb-tls-pairing._tcp` and
`_adb-tls-connect._tcp` via mDNS [s]. A SPAKE2 exchange over TLS uses the code
to authorize the client's ADB public key for a separate TLS connection [s].
The helper takes the first resolved port and connects on loopback [s]. Its
command client authenticates with the paired key and skips server certificate
verification [s].

### The paired key is the boundary

Keep the paired ADB private key in app-private storage and exclude it from backup
and export. Authorize every trigger that uses the key or changes debugging state,
including fixed redeploy actions. Keep internal receivers non-exported. Require
a signature permission for same-signer callers that need a cross-app entry point.
Deliver notification replies through an explicit `PendingIntent` scoped to a
non-exported receiver, with mutability limited to the reply action.

The pinned helper's exported, permission-free `SpikeReceiver` passes
broadcast-supplied ADB arguments to its paired client, so any app in the same
Android user can delegate command execution to UID 2000 while the paired
transport is available [s]. `DeployReceiver` ignores broadcast input and uses
a fixed script and bundled daemon [s]. Any app in that Android user can still
request a redeploy, which can interrupt an active daemon [s].
At the pin, `PairReplyReceiver` and `EnableReceiver` are exported without a
sender permission [s].

## Example

[examples/detach.c](../examples/detach.c) illustrates the session detach and
then executes an absolute program path with its original argument boundaries.

```c
    fork_and_exit_parent();
    if (setsid() == -1) {
        perror("setsid");
        _exit(1);
    }
    fork_and_exit_parent();
```

The parent exits before the final `execv()`, so its status cannot establish
that the target is up [s].

## How it fails

| symptom | cause | next check |
| --- | --- | --- |
| the daemon runs but `adb shell` waits | a descendant still holds the shell's descriptors [s] | check inherited descriptors as well as stdin, stdout and stderr |
| the daemon disappears when the `adbd` service stops | init can clean up the service's cgroup [s] | check the service lifetime and the daemon's cgroup |
| pairing succeeds but the ADB connection fails | the connect endpoint is absent, stale or misidentified [s] | check that the connect service is still advertised and resolve its port |

## By domain

The client stays in **app** and the daemon and commands run in **shell** [s].
A launch from **root** inherits root credentials unless they are dropped [s].

## Evidence

- The bridge checks the socket peer UID before verifying an Ed25519 signature
  over both nonces, the timestamp and both ephemeral public keys [s]. The daemon
  embeds the client's long-term public key [s]. This relay key is separate from
  the ADB pairing key [s].
  [Pinned daemon source](https://github.com/jronminh/termux-adb-bridge/blob/dacc4897acd7eceee343f8a96ebbbe14b4989d19/build/relaysh/relaysh-daemon.c)
- With the double fork and redirected stdio, `adb shell` returns 0 and a second
  ADB command still finds the detached supervisor, measured on Samsung Galaxy
  S10e (SM-G970W), Android 12, 2026-11-11 [m].
- [Linux daemon conventions](https://man7.org/linux/man-pages/man7/daemon.7.html), [AOSP shell service](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/daemon/shell_service.cpp#583),
  [Android init service cleanup](https://android.googlesource.com/platform/system/core/+/refs/heads/main/init/service.cpp#204).
- [Android 11 support](https://developer.android.com/studio/run/device), [AOSP wireless ADB](https://android.googlesource.com/platform/packages/modules/adb/+/HEAD/docs/dev/adb_wifi.md),
  [AOSP pairing exchange](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/pairing_connection/pairing_connection.cpp#299),
  [Pinned ADB command client](https://github.com/jronminh/termux-adb-bridge/blob/dacc4897acd7eceee343f8a96ebbbe14b4989d19/build/adbwire/adbwire.c#L1058),
  [Pinned helper](https://github.com/jronminh/termux-adb-bridge/tree/dacc4897acd7eceee343f8a96ebbbe14b4989d19/build/adbwifi-helper), [Android receiver permissions](https://developer.android.com/privacy-and-security/risks/insecure-broadcast-receiver).
