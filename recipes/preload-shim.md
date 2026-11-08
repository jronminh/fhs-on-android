# Deliver a DSO by `ld.so.preload`, not `LD_PRELOAD`

**Goal.** The tree's loader preloads the tree's shim — for every program,
without the launcher setting a variable, and without a host `LD_PRELOAD`
reaching the tree's glibc and aborting it at start. **Isolation 2.**

**Basis.** **Recorded** — the project's prefix delivery: `<prefix>/etc/ld.so.preload`
plus one loader hunk that drops an inherited `LD_PRELOAD` (deb-native's
`dn-glibc-prefix` spec and the loader patch). Not re-run here; the phones have no
tree with a patched loader. The failure it prevents is [s].

**Prerequisites.**

- a tree whose loader is the one you control (patched or configured for it);
- the shim built against the **tree's** glibc (the ABI floor: a shim built
  against a newer glibc fails to load with a version error);
- the tree's `etc/` writable.

**Time and size.** A minute. One line in one file.

**Steps.**

1. Put the shim inside the tree, at a path valid **from inside the tree**:

   ```sh
   cp dnlane.so "$T/usr/lib/deb-native/dnlane.so"
   printf '%s\n' /usr/lib/deb-native/dnlane.so > "$T/etc/ld.so.preload"
   ```

2. Patch the loader to ignore an inherited `LD_PRELOAD` — the project's one
   loader hunk. Without it, a host shim built for a bionic or newer glibc
   aborts every program in the tree before it starts.

3. Prove both halves from the entry ([an entry script](entry-script.md)):

   ```sh
   cat /proc/self/maps | grep -q dnlane && echo "shim: mapped"
   LD_PRELOAD=/nonexistent.so ./a-program && echo "inherited preload: ignored"
   ```

**Expected.** Every dynamic program in the tree has the shim mapped, and a
`LD_PRELOAD` set outside the tree changes nothing. A static binary has nothing
preloaded (it never reaches the loader), which is the shim's own blind spot.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| every program aborts at start, naming a version or a preload | a host `LD_PRELOAD` reached an unpatched loader | the loader hunk; `unset LD_PRELOAD` as a test |
| nothing is mapped, and no error | the path in `ld.so.preload` is the host's, not the tree's | the line is a path *inside* the tree |
| some programs are mapped, others abort | the shim was built against another glibc | rebuild it against the tree's libc |
| a static program sees no shim | expected: a static binary never reaches the loader | it needs [a tracer](../methods/tracer.md) |

**Undo.**

```sh
: > "$T/etc/ld.so.preload"
```

Keep the loader patch: an empty preload file is harmless, and re-applying the
hunk after a rollback is the kind of thing that gets forgotten.

**Cost.** The preload file is a path, so moving the tree needs no change (the
path is guest-relative) — but the patch is a glibc patch, and a glibc update
brings it back. Record which libc the shim was built against
([the loader method](../methods/loader.md), "What it costs").
