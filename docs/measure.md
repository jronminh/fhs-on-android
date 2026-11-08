# 9. How to measure on a phone

Phones are noisy computers. They thermal-throttle, they vary by 10–20% between
identical runs, and every one of them is a different kernel. Almost every
"method X is faster" claim on the internet is one run on one device with no
control.

This page is the small set of rules that make a number worth quoting.

## Rules

1. **Interleave A and B.** Never run all of A, then all of B: the phone's thermal
   state changes in between. Run A, B, A, B, and compare medians.
2. **Take the minimum, report the median.** The minimum is the least-contaminated
   sample; the median is what a person feels. Report both if they disagree by
   more than 20%.
3. **Name the device, the kernel and the date.** `uname -r` and
   `getprop ro.build.version.release`, every time.
4. **Separate wall time from syscall counts.** Wall time tells you whether a
   person is waiting; stop counts tell you *where* the cost is. A method can have
   40% fewer stops and be 5% slower in wall time — both are true and both matter.
5. **Measure the workload you actually have.** Metadata-heavy (`find`, `apt`,
   `git status`) and CPU-heavy (a compiler, a benchmark loop) have completely
   different ratios under every method here.
6. **Do not `strace` a traced tree.** You cannot attach a second `ptrace`
   supervisor. Use the runtime's own counters, or reproduce the problem outside
   the tree.
7. **Pin and warm up.** `taskset`/`chrt` where available, one warm-up run, screen
   on or off but *consistently* ([the screen's power state changes results on
   some devices](#what-moves-the-numbers)).

## The bench set

Five workloads that between them expose every layer. Run each 5 times,
interleaved with the baseline.

| workload | command | exposes |
| --- | --- | --- |
| metadata walk | `find /usr -type f \| wc -l` | path translation cost (the worst case) |
| link/stat | `ls -lR /usr/share >/dev/null` | `stat`, `readlink`, `realpath` |
| process spawn | a loop of 300 × `/bin/true` | exec cost, the userland exec's win |
| package install | `apt-get install -y --reinstall figlet` | maintainer scripts, hooks, the whole bar-2 path |
| build | `tar xf lua-5.4.7.tar.gz && cd lua-5.4.7 && make -j1` | a compiler's syscall mix, close to real work |

Baseline is the same workload **outside** the tree, in Termux or under
`adb shell`: `find /system` is not a baseline for `find /usr`; use something
with a comparable file count and namespace.

## An example of what a result looks like

Measured on one Samsung S10e, Android 12, kernel 4.14 [m, 2026-10], using the
hybrid method's reference implementation. These are *example* numbers, not a
promise about your phone:

| workload | inside the tree | native baseline | ratio |
| --- | --- | --- | --- |
| `find` over ~13,000 files | 0.13 s | 0.08 s | 1.6× |
| Lua 5.4 `make -j1` | ~13 s | ~10 s | 1.3× |
| 300 × `true` (spawn) | — | — | the userland exec cut stops by ~42% against the loader path |

Read that as "the hybrid method is close to native on this device", not as "the
hybrid method is 1.3×". A `proot`-based tree on the same phone would be a very
different table, and that is the point of measuring.

## What moves the numbers

- **Thermals.** A phone at 45 °C is not the same computer as the same phone at
  30 °C. Let it rest between rounds; check `/sys/class/thermal/thermal_zone*/temp`.
- **The screen.** On some devices, screen-off changes the CPU governor's
  behaviour and the result; on others it does not. Pick one and say which.
- **The big.LITTLE split.** Cores 4–7 are often ~20% faster than 0–3 on the same
  phone. `taskset` the workload or your runs are comparing schedulers.
- **Other radios and services.** Wi-Fi scanning, a sync, a system update — all
  noise. Airplane mode is not a neutral baseline either: it changes the CPU
  idle behaviour on some phones.
- **The filesystem.** App data vs `/data/local/tmp` vs `/sdcard` are three
  different filesystems with three different behaviours; never compare a number
  taken in one with a number taken in another.
- **Page cache.** First run is cold. Always discard the first run, and never
  quote it.

## Reporting

A quotable result has six fields:

```
device: SM-G970W, Android 12, kernel 4.14.190, host=Termux
date: 2026-10-26
method: hybrid (shim on / shim off / tracer only)
workload: find /usr -type f | wc -l      runs: 5, interleaved
result: median 0.13 s, min 0.12 s (baseline median 0.08 s)
notes: screen off, thermal 31 °C, cold run discarded
```

If you send a result without those, it will be read as an anecdote — including
by you, six months later.
