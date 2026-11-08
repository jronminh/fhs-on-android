# AGENTS.md

Agent-first notes. The guide is [README.md](README.md); this file says how to use
the repository, not what it contains.

## The shape

- `tree/` — building the FHS tree: two supplies ([glibc](tree/glibc.md),
  [the host's own material](tree/bionic.md)), the layout, where it lives
  ([durability](tree/durability.md)), and what changes on a rooted phone
  ([root](tree/root.md)).
- `methods/` — how a Linux program is made to run inside it, one page per
  method, each with its isolation level and its cost.
- `reference/` — the platform (three gates), the three domains, the failure
  catalogue, measurement, prior art, evidence.

Every method page has the same six sections: what it buys, what it costs, an
example from real code, how it fails, by domain, evidence. Every method is valid;
the guide states the cost and does not rank the method. The cost axis used most
is [isolation](README.md#the-isolation-scale).

## Enter from here

| the situation | open |
| --- | --- |
| the tree does not exist yet | [tree/glibc.md](tree/glibc.md) or [tree/bionic.md](tree/bionic.md) |
| the tree exists, a program will not run | [reference/limits.md](reference/limits.md) |
| choosing between approaches | [methods/README.md](methods/README.md) |
| a known goal, step by step | [recipes/README.md](recipes/README.md) |
| what to cook with | [recipes/tools.md](recipes/tools.md) |
| "does this phone allow it" | [examples/probe.sh](examples/probe.sh) |
| what is known | [reference/evidence.md](reference/evidence.md) |
| progress, and what is next | [TODO.md](TODO.md) |
| the examples, and what each proves | [reference/examples.md](reference/examples.md) |
| what is not a recipe yet, and why | [recipes/backlog.md](recipes/backlog.md) |

## Rules

1. **Label what you add**: `[m]` measured, `[s]` from source or spec, `[u]` unverified.
   An unlabelled factual sentence is a bug ([CONTRIBUTING](CONTRIBUTING.md)).
2. **One owner per rule.** Do not add a second place that decides what a path or
   an identity means.
3. **Never assume a domain.** Read `id -u`, `Seccomp:` and `CapEff:` before acting
   ([reference/domains.md](reference/domains.md)).
4. **Never write to `system`/`vendor`, or flash `boot`, without a recovery path off the
   phone.**
5. **Unmount before you delete.** Never `rm -rf` a tree while `/dev` is still bound into
   it: the delete descends into the live `/dev` and unlinks device nodes. Lazy-unmount,
   verify with `mount | grep`, then delete. This is the one mistake in this repository
   that took a phone off USB (`tree/root.md#deleting-a-tree-safely`).
6. **Examples are illustrations, not tools.** `examples/` holds small files that
   show a mechanism; they are not the runtime, and the guide is not a runbook. It
   carries contracts, trade-offs and failure signatures.

## Scope

A glibc userland or the host's own material; musl is out, with its reason in
[README.md](README.md#scope).
