# Contributing

The most valuable contribution here is a **correction with a device and a date**
— a claim in this repository that is false on your phone.

## What to send

1. **A contradiction.** Quote the sentence, say what happened instead, and give
   the device, Android version, kernel, domain (app, shell, root), host and the
   date. If it is a speed claim, include the six fields from
   [measure](./reference/measure.md#reporting).
2. **A missing failure.** A symptom you hit that
   [limits](./reference/limits.md) does not list, with the command, the exact error,
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
  [the methods](./methods/README.md) is right somewhere; if yours is right
  everywhere, the description is wrong.
- A **verdict** where a trade-off belongs. Every method is valid; a page says what
  it buys, what it costs, and when you would pick it. "Wrong" is not a
  description, and "the right way" is not one either.
- A musl program or package (Alpine and friends). The guide is scoped to a glibc
  program and its packages ([scope](README.md#the-methods-side-by-side)):
  not because musl is wrong, but because no measurement here covers it.
- A rewrite of the prose into a link farm. Depth over coverage.

## Labels

Every non-obvious statement carries a label:

- **[m]** measured — you ran it on a named device, on a date, and can say how;
- **[s]** read in a specification or in source;
- **[u]** unverified — an assumption or a report you have not reproduced.

If you add a claim that is not a definition or a consequence, add its label.

## Detail level

A **method page** is 55-95 lines and has these sections, in this order:

1. what it is, and its isolation level (1-4 lines);
2. **What it buys** - 3-5 bullets, each a consequence, not an adjective;
3. **What it costs** - 3-5 bullets, each naming the mechanism of the cost;
4. **Example** - a link to a file in `examples/`, with a short excerpt of it, and
   the one thing it demonstrates. A method described without one is not believed;
   the example must live in this repository, so the guide stays self-contained;
5. **How it fails** - a table of symptom -> cause -> next check, at least two rows;
6. **By domain** - 1-3 lines on how app, shell and root change it;
7. **Evidence** - at least one labelled claim, with where it came from.

A **tree page** is 55-110 lines and carries a contract, the numbers, and a failure
signature. Never a transcript: no step-by-step commands to copy. Every number is
labelled, and every failure is named by its observable string.

## Style

- English, plain, present tense, no marketing.
- Write for an agent that must act on the sentence, and for a person who must
  judge it: state the scope, the trade-off and the failure signature; leave the
  step-by-step to the tools.
- One idea per paragraph. Tables for comparisons; prose for reasons.
- Error strings in backticks, exactly as they appear (they vary between shells —
  say which shell).
- No images of terminals for text that can be copied.

## Process, such as it is

Single maintainer, no CI. Open an issue or a pull request; one claim per
paragraph makes review a five-minute job. Changes to `reference/limits.md` that
correct a symptom→cause pair are merged fastest.
