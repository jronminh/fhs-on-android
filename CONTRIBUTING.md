# Contributing

The most valuable contribution here is a **correction with a device and a date**
— a claim in this repository that is false on your phone.

## What to send

1. **A contradiction.** Quote the sentence, say what happened instead, and give
   the device, Android version, kernel, host (Termux, APK, `adb shell`, root) and
   date. If it is a speed claim, include the six fields from
   [docs/06](docs/06-measure.md#reporting).
2. **A missing failure.** A symptom you hit that
   [docs/05](docs/05-limits.md) does not list, with the command, the exact error,
   and what fixed it. Rows marked *unfixable* are especially welcome when you can
   show one that is not.
3. **A missing method or project.** With what it does differently, on which
   axis, and what it costs. Marketing descriptions are not accepted; a
   trade-off is.
4. **A typo, a broken link, a table that does not render.** Always welcome, no
   process.

## What not to send

- An unlabelled performance number. `10× faster` is not a claim, it is a
  sentence.
- A method described as universally best. Every method in
  [docs/02](docs/02-methods.md) is right somewhere; if yours is right
  everywhere, the description is wrong.
- A rewrite of the prose into a link farm. Depth over coverage.

## Labels

Every non-obvious statement carries a label:

- **[m]** measured — you ran it on a named device, on a date, and can say how;
- **[s]** read in a specification or in source;
- **[u]** unverified — an assumption or a report you have not reproduced.

If you add a claim that is not a definition or a consequence, add its label.

## Style

- English, plain, present tense, no marketing.
- One idea per paragraph. Tables for comparisons; prose for reasons.
- Error strings in backticks, exactly as they appear (they vary between shells —
  say which shell).
- No images of terminals for text that can be copied.

## Process, such as it is

Single maintainer, no CI. Open an issue or a pull request; one claim per
paragraph makes review a five-minute job. Changes to `docs/05` that correct a
symptom→cause pair are merged fastest.
