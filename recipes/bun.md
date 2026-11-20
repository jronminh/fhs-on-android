# Run Bun-based programs in Termux

**Goal.** Run Bun, Claude Code or opencode from an upstream Linux arm64 binary
in the Termux app domain, using Termux's glibc loader. **Isolation 1.**

**Basis.** **Recorded** [m] on Samsung Galaxy S10e (SM-G970W), Android 12,
kernel 4.14.190, in the guide dated 2026-10-13. The run used
`glibc-runner` 2.0-3, Claude Code 2.1.296, opencode 1.19.0 and Bun 1.4.3.
This recipe has no FOA device run. Other Android releases, authenticated CLI
sessions, their tool calls and long sessions are unverified [u].

**Prerequisites.** An aarch64 Termux session with `glibc-runner` from
`glibc-repo`, plus `curl`. Use `jq` for Claude Code, `tar` for opencode and
`unzip` for Bun. Prepare the session with `pkg install glibc-repo`, then
`pkg install glibc-runner curl` and the tools for the chosen program [s].
[Termux glibc repository](https://github.com/termux/glibc-packages)

**Time and size.** Installation time depends on the downloads [u]. Plan for
750 MiB free to try all three, in addition to the Termux packages [u].

**Steps.**

1. Check that the session is the Termux app and that `grun` is on `PATH`.
   Use a fresh directory. Stop if `mkdir "$B"` reports that it already exists.

   ```sh
   id -u
   grep -E '^(Seccomp|CapEff):' /proc/self/status
   command -v grun
   B="$HOME/.local/share/foa-bun"
   mkdir -p "$HOME/.local/share" && mkdir "$B" && mkdir "$B/bin" "$B/libexec"
   ```

2. Download the programs to try. Use the glibc builds. For Claude Code, check
   the binary against the release manifest before installing it [s].

   **Claude Code**

   ```sh
   (
       set -e
       cd "$B/libexec"
       url=https://downloads.claude.ai/claude-code-releases/2.1.296
       curl -fsSL "$url/manifest.json" -o claude-manifest.json
       sum=$(jq -er '.platforms["linux-arm64"].checksum' claude-manifest.json)
       curl -fsSL "$url/linux-arm64/claude" -o claude.download
       printf '%s  claude.download\n' "$sum" | sha256sum -c -
       mv claude.download claude
       chmod 755 claude
   )
   ```

   **opencode**

   ```sh
   curl -fsSL https://github.com/anomalyco/opencode/releases/download/v1.19.0/opencode-linux-arm64.tar.gz \
       -o "$B/opencode.tar.gz" && tar -xzf "$B/opencode.tar.gz" -C "$B/libexec" &&
       chmod 755 "$B/libexec/opencode" && rm "$B/opencode.tar.gz"
   ```

   **Bun**

   ```sh
   curl -fsSL https://github.com/oven-sh/bun/releases/download/bun-v1.4.3/bun-linux-aarch64.zip \
       -o "$B/bun.zip" && unzip -j "$B/bun.zip" bun-linux-aarch64/bun -d "$B/libexec" &&
       chmod 755 "$B/libexec/bun" && rm "$B/bun.zip"
   ```

3. Add a launcher for each downloaded program. Add the launchers to `PATH` for
   this session.

   ```sh
   for name in claude opencode bun; do
       [ -x "$B/libexec/$name" ] || continue
       printf '#!%s/bin/sh\nexec "%s/bin/grun" "$HOME/.local/share/foa-bun/libexec/%s" "$@"\n' \
           "$PREFIX" "$PREFIX" "$name" > "$B/bin/$name"
       chmod 755 "$B/bin/$name"
   done
   FOA_BUN_OLD_PATH=$PATH
   export PATH="$B/bin:$PATH"
   ```

4. Run the checks for the programs installed.

   ```sh
   claude --version
   claude auth status
   opencode --version
   bun --version
   ```

5. If Bun is installed, check whether the runner preserves a single argument
   containing a space.

   ```sh
   bun -e 'console.log(process.argv.at(-1))' -- 'a b'
   ```

**Expected.** `claude --version` reports `2.1.296`, `opencode --version` reports
`1.19.0`, and `bun --version` reports `1.4.3`. On a fresh install
`claude auth status` starts and reports that no login exists [m].

The argument check prints `a b` when the runner preserves the original argument
boundaries. In `glibc-runner` 2.0-3, `grun` expands `$@` unquoted and splits
space-containing arguments even when the launcher quotes them [s].
[Runner entry point](https://github.com/termux-pacman/glibc-packages/blob/main/gpkg/glibc-runner/glibc-runner#L5)

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `./bun: not found` when run directly [m] | Android lacks the binary's `PT_INTERP`, `/lib/ld-linux-aarch64.so.1` [s] | run it through the wrapper |
| the npm installer reports `android`, or `claude` reports `native binary not installed` [s] | the installer has no matching native build [s] | use the release binary in step 2 |
| the argument check loses part of `a b` [s] | `glibc-runner` 2.0-3 splits arguments containing spaces [s] | use a runner version that passes step 5 for commands requiring those arguments |
| a child finds glibc `bash` instead of Termux `bash` [m] | `grun` prepends `$PREFIX/glibc/bin` [s] | check the child's `PATH` and tool path before testing CLI tools |
| `git` or `rg` is missing [s] | the Termux session lacks the tool | check `command -v git rg` and install `git` or `ripgrep` where needed |
| a Bun child running `ls /` exits 2 [m] | unknown [u] | compare its stderr and resolved `ls` with native Termux |
| `bad ELF magic`, `CANNOT LINK EXECUTABLE` or `invalid ELF header` [u] | inherited `LD_LIBRARY_PATH` or `LD_PRELOAD` may mix bionic and glibc [u] | retry from a fresh Termux session with no custom linker variables |
| `Permission denied` or `cannot execute: Success` [u] | the executable bit may be missing [u] | check mode on both launcher and binary |
| `EACCES` under `/tmp` [u] | the process may lack a writable temporary directory [u] | set `TMPDIR` to a directory it can write |
| a CLI's internal `grep` reports `-G: error while loading shared libraries` [u] | self-exec through `/proc/self/exe` may resolve the explicitly invoked loader [u] | reproduce inside the CLI's shell tool, beyond `--version` |
| a Bun-based CLI segfaults on a newer kernel [u] | an older Bun runtime may hit the `epoll_pwait2` TLS fault [s] | test a build with the upstream fix or set `BUN_FEATURE_FLAG_DISABLE_EPOLL_PWAIT2=1` where supported. Use a workload beyond `--version`. [Bun fix](https://github.com/oven-sh/bun/pull/32490) |

**Undo.** In the session that ran step 3, restore its path. Remove the recipe's
directory. The Termux prerequisites and any data from later interactive use
belong to the Termux session or application.

```sh
if [ "${FOA_BUN_OLD_PATH+x}" ]; then
    export PATH="$FOA_BUN_OLD_PATH"
    unset FOA_BUN_OLD_PATH
fi
rm -rf "$HOME/.local/share/foa-bun"
```

**Cost.** Plain `grun` selects the loader and leaves the downloaded binary
intact, the level-1 path in [the loader method](../methods/loader.md#the-three-techniques)
[s]. Child tool lookup can change with `PATH` [m]. An updater that replaces a
binary at the same path should leave the wrapper usable [u]. Self-update was
not exercised [u]. [Runner source](https://github.com/termux-pacman/glibc-packages/blob/main/gpkg/glibc-runner/glibc-runner.sh)

**Evidence.** The same run fetched `opencode models` and exercised Bun `fetch`,
file I/O, `bun install`, `require` and `child_process` spawn [m]. It recorded
`./bun: not found` without the wrapper [m]. The older failure reports in the
table have no reproduction in that Termux run [u]. The earlier `patchelf` setup
also reported a crash after editing the ELF and a missing interpreter when an
update replaced the edited file [u]. The steps here leave `PT_INTERP` intact [s].

Adapted from [bun-termux by jronminh](https://github.com/jronminh/bun-termux/tree/e25ab89a8f38ecb0f7e2ac6dd869adcddfc1e3f4)
under [CC BY 4.0](../LICENSE). This adaptation pins the binary downloads and
keeps the programs and launchers under one removable directory. The downloaded
programs keep their upstream licenses.
