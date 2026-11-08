# Keep a child running without a PID 1

**Goal.** A process that comes back when it dies, without init, cgroups or a
service manager. **Isolation 0.**

**Tested on.** The same three phones, 2026-11-08 [m]: sdk 29, 31 and 35, no root.
Result on all three: **3 starts, 3 respawns, 0 left running** after the test.

**Prerequisites.** `adb`; a tree directory; nothing else.

**Time and size.** A few seconds to test; a shell loop in production.

**Steps.**

1. Write the child and the loop:

   ```sh
   P=/data/local/tmp/sup; mkdir -p "$P"
   cat > "$P/child.sh" <<'EOF'
   #!/system/bin/sh
   echo "start $$" >> /data/local/tmp/sup/log
   sleep 30
   EOF
   cat > "$P/sup.sh" <<'EOF'
   #!/system/bin/sh
   P=/data/local/tmp/sup; i=0
   while [ $i -lt 3 ]; do
       "$P/child.sh" &
       pid=$!
       sleep 1
       kill $pid 2>/dev/null
       i=$((i+1))
       echo "respawn $i" >> "$P/log"
   done
   EOF
   chmod 755 "$P/child.sh"
   ```

2. Run it and count:

   ```sh
   sh "$P/sup.sh"
   echo "starts=$(grep -c start "$P/log") respawns=$(grep -c respawn "$P/log")"
   ps -A | grep -c '[c]hild.sh'
   ```

**Expected.**

```
starts=3 respawns=3
0
```

**If it fails.**

| symptom | cause | next check |
| --- | --- | --- |
| the child starts once and never returns | the loop exited, or the parent was killed with the group | the loop must stay the parent of every child |
| a boot hook kills the supervisor | `exec_background` ends when the script returns, and init kills the process group | use an init service for a long-lived process ([durability](../tree/durability.md#the-boot-image-frame)) |
| respawn storm: hundreds of starts | no delay and no budget | a restart threshold and a delay, e.g. 5 s |

**Undo.** `pkill -f child.sh 2>/dev/null; rm -rf /data/local/tmp/sup`

**Cost.** A shell loop is the whole supervisor: no cgroups, no limits, no ordering
between services. It is enough for one process; it is not an init.
