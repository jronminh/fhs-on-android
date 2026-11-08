# Recipes

A recipe is a goal, a short procedure and an expected result. The pages in
[methods](../methods/README.md) explain and price; these pages say what to type.
Steps are allowed here and only here.

## By goal

| goal | recipe | root | isolation | measured |
| --- | --- | --- | --- | --- |
| a tree of commands, no root, no download | [shell-tree](shell-tree.md) | no | 0 | yes |
| an FHS root that runs a static binary | [chroot-busybox](chroot-busybox.md) | yes | 4 | yes |
| an FHS root that runs a dynamic glibc program | [chroot-glibc](chroot-glibc.md) | yes | 4 | yes |
| the Debian files those recipes need, built on a host | [ingredients-debian](ingredients-debian.md) | no | - | yes, on a host |

## By constraint

| constraint | start with |
| --- | --- |
| no root | [shell-tree](shell-tree.md) |
| no busybox on the phone | [shell-tree](shell-tree.md), which needs nothing |
| Android 10 or older | [shell-tree](shell-tree.md); `readelf` is absent before Android 12, so the loader checks need another route |
| a rooted phone | [chroot-busybox](chroot-busybox.md), then [chroot-glibc](chroot-glibc.md) |
| about 2 MB of free space | both chroot recipes: 1.7 MB and 2.1 MB |
| no glibc userland to copy files from | [ingredients-debian](ingredients-debian.md): 64 s, 225 MB on a host |

## What you cook with

The tools and the choices between them, from the shell you write scripts in to
the host that builds the ingredients: [tools.md](tools.md).

## The shape of a recipe

1. **Goal**: one sentence, and the isolation level it settles at;
2. **Tested on**: device, Android version, kernel, date, and the label;
3. **Prerequisites**: the tools and the phone state it assumes;
4. **Time and size**: how long, how much space;
5. **Steps**: numbered commands, each runnable as written;
6. **Expected**: the output, so it is clear when the recipe is done;
7. **If it fails**: symptom, cause, next check;
8. **Undo**: the commands that put the phone back;
9. **Cost**: what the recipe gives up, in the terms of the
   [isolation scale](../README.md#the-isolation-scale).

## Rules

- **Every recipe says what it was tested on.** A recipe without a run is a
  sketch, and sketches are listed below, unnumbered.
- **Every recipe ends with undo.** A recipe that cannot be reversed is not
  offered.
- **Steps are minimal.** A recipe that explains belongs in `methods/`; a recipe
  that guesses is a sketch.
- **No recipe whose last run was on a different Android version from the one in
  your hand, without saying so.**

## Sketches, not recipes yet

These have a design and no run in this repository. They are unnumbered on
purpose: do not follow one as if it were checked.

| sketch | what would make it a recipe |
| --- | --- |
| an imported glibc userland built with `debootstrap` | one full build on one phone, with time and size, then `apt-get install figlet` |
| `PT_INTERP` rewritten in every `.deb` before `dpkg` | a run against a real package set, with the loader path and the failure mode |
| a glibc program without root (loader from `PT_INTERP`, shim or tracer) | a runtime that starts the tree on an unrooted phone, and one run of one program |
| a tree that survives a factory reset (boot ramdisk) | a simulated reset on a rooted phone: remove the `/data` state, reboot, touch nothing |
