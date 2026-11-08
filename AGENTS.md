# AGENTS.md

Agent-first notes. The guide is [README.md](README.md); this file says how to use
the repository, not what it contains.

## The shape

- `tree/` — building the FHS tree: two supplies ([glibc](tree/glibc.md),
  [the host's own material](tree/bionic.md)), the layout, where it lives
  ([durability](tree/durability.md)), and what changes on a rooted phone
  ([root](tree/root.md)).
- `methods/` — how a Linux program is made to run inside it, one page per
  method, each with its isolation level and its price.
- `reference/` — the platform (three gates), the three domains, the failure
  catalogue, measurement, prior art, evidence.

Every method page has the same six sections: what it buys, what it costs, an
example from real code, how it fails, by domain, evidence. Every method is valid;
the guide states the price and never ranks the method. The price that decides most
is [isolation](README.md#the-isolation-scale).

## Enter from here

| the situation | open |
| --- | --- |
| the tree does not exist yet | [tree/glibc.md](tree/glibc.md) or [tree/bionic.md](tree/bionic.md) |
| the tree exists, a program will not run | [reference/limits.md](reference/limits.md) |
| choosing between approaches | [methods/README.md](methods/README.md) |
| "does this phone allow it" | [examples/probe.sh](examples/probe.sh) |
| what is actually known | [reference/evidence.md](reference/evidence.md) |
| the examples, and what each proves | [reference/examples.md](reference/examples.md) |

## Rules that are not negotiable

1. **Label what you add**: `[m]` measured, `[s]` from source or spec, `[u]` unverified.
   An unlabelled factual sentence is a bug ([CONTRIBUTING](CONTRIBUTING.md)).
2. **One owner per rule.** Do not add a second place that decides what a path or
   an identity means.
3. **Never assume a domain.** Read `id -u`, `Seccomp:` and `CapEff:` before acting
   ([reference/domains.md](reference/domains.md)).
4. **Never write to `system`/`vendor`, or flash `boot`, without a recovery path off the
   phone.**
5. **Examples are illustrations, not tools.** `examples/` holds small files that
   show a mechanism; they are not the runtime, and the guide is not a runbook. It
   carries contracts, trade-offs and failure signatures.

## Scope

A glibc userland or the host's own material; musl is out, with its reason in
[README.md](README.md#scope).
