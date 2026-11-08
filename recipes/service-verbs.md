# A command with status, check and adopt

**Goal.** One file in the tree that answers three questions: what is the state
(`status`), is it in line with intent (`check`), and record today's state as intent
(`adopt`). **Isolation 0.**

**Tested on.** The same three phones, 2026-11-08 [m]: sdk 29, 31 and 35, no root.

**Prerequisites.** `adb`; a tree directory you own; nothing else.

**Time and size.** A minute. A few hundred bytes.

**Steps.**

1. Write the command. The tree's root comes from the script's own location:

   ```sh
   T=/data/local/tmp/svc; mkdir -p "$T/bin" "$T/etc"
   cat > "$T/bin/devstatus" <<'EOF'
   #!/system/bin/sh
   TREE=${TREE:-${0%/*}/..}
   kv() { printf "%s=%s\n" "$1" "$2"; }
   VERBS="status check adopt"
   svc_status() { kv sdk "$(getprop ro.build.version.sdk)"; kv adb "$(settings get global adb_enabled 2>/dev/null)"; }
   svc_check() {
       f="$TREE/etc/intent"; rc=0
       [ -f "$f" ] || { echo "diff intent: missing"; return 1; }
       [ "$(grep '^sdk=' "$f" | cut -d= -f2)" = "$(getprop ro.build.version.sdk)" ] || { echo "diff sdk"; rc=1; }
       return $rc
   }
   svc_adopt() { printf "sdk=%s\n" "$(getprop ro.build.version.sdk)" > "$TREE/etc/intent"; echo adopted; }
   verb=${1:-status}
   case " $VERBS " in *" $verb "*) "svc_$verb" ;; *) echo "usage: $VERBS"; exit 64 ;; esac
   EOF
   chmod 755 "$T/bin/devstatus"
   ```

2. Run the three verbs, then make `check` fail on purpose:

   ```sh
   TREE=$T "$T/bin/devstatus" status
   TREE=$T "$T/bin/devstatus" adopt
   TREE=$T "$T/bin/devstatus" check; echo "rc=$?"
   printf 'sdk=1\n' > "$T/etc/intent"
   TREE=$T "$T/bin/devstatus" check; echo "rc=$?"
   TREE=$T "$T/bin/devstatus" adopt
   TREE=$T "$T/bin/devstatus" check; echo "rc=$?"
   ```

**Expected.**

```
sdk=31
adb=1
adopted
rc=0
diff sdk
rc=1
adopted
rc=0
```

The first line is the phone's own sdk: 29, 31 and 35 on the three devices.

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| `/tmp: No such file or directory` | Android has no `/tmp`; `TMPDIR` is `/data/local/tmp` | write state under the tree, not under `/tmp` |
| `check` always passes | it compares nothing, or reads intent from the wrong path | print the file it reads |
| `check` exits 0 on failure | the last command in the function succeeded | `return $rc` as the last line |

**Undo.** `rm -rf /data/local/tmp/svc`

**Cost.** You write the command, and `check` is only as good as the rule it encodes;
a command that cannot state intent cannot heal ([state](../tree/README.md#state)).
