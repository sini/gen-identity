# gen-identity — agent cheatsheet

## Scope

The gen ecosystem's **one minting authority**. `hashIdentity` turns a kind tag, a label list and
a value lookup into `"<kind>:<sha256hex>"`, over a bounded type-tagged canonical encoding of
inert Nix values. Nothing else in the ecosystem mints (ADR-0016 ruling 5).

Zero dependencies of any kind. `lib` is a bare attrset, not a function.

## Not this library's job

| Need                                                                                         | Owner                                                                                                                                                                                                                                                                                                                            |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Identity-key REFLECTION, `id_hash` stamping, kinds, registries                               | `gen-schema` — **`gen-schema/lib/id-hash.nix`**. It decides which of a kind's declared options are identity keys and stamps the field; it reads option metadata and builds options with the module system. It calls this library and does not belong to it                                                                       |
| Intensional identity and conservative equality over FUNCTIONS                                | `gen-algebra` — **`gen-algebra/lib/intensional.nix`**                                                                                                                                                                                                                                                                            |
| Structural type checking                                                                     | `gen-types`                                                                                                                                                                                                                                                                                                                      |
| General pure utilities                                                                       | `gen-prelude`                                                                                                                                                                                                                                                                                                                    |
| Gate digests                                                                                 | `gen-class` — ADR-0016 ruling 5's own carve-out: a gate digest is not an identity                                                                                                                                                                                                                                                |
| Aspect KEY derivation — paths, path keys, guard keys, body keys                              | `gen-aspects` — **`gen-aspects/lib/identity.nix`**, cited by repository AND path deliberately: it is named `identity.nix` and it is not this library's concern                                                                                                                                                                   |
| Crossing / binding identity helpers                                                          | `gen-bind` — **`gen-bind/lib/identity.nix`**, likewise named `identity.nix` and likewise not this library's                                                                                                                                                                                                                      |
| Dedup and trace keys                                                                         | their own libraries — `gen-view` `hashTrace` (landed there from the now-retired `gen-edge`, ADR-0010 §3; the retired copy still evaluates in the archived repository because that surface is marked rather than cut), `gen-memo` `hashOf`, `gen-resolve` `classkey`. Whether those are identities or digests is not settled here |
| Digest / dedup keys that want a canonical encoding and explicitly NOT a kind-tagged identity | Not served yet — see *When the encoder publishes* below                                                                                                                                                                                                                                                                          |

★ **THREE FILES IN THIS ECOSYSTEM ARE CALLED `identity.nix`, AND NONE OF THEM IS THIS LIBRARY.**
gen-aspects' and gen-bind' still are; gen-schema's was renamed to `id-hash.nix` when the mint left
it, precisely because a file called `identity.nix` containing no identity mint, beside a LIBRARY
called gen-identity, is a reader's trap. They are cited above by repository AND path for that
reason. Writing this table down is what stops this library becoming the place every hashing
question lands — a hazard its name makes larger rather than smaller.

## Exports

Entry: `inputs.gen-identity.lib` (flake), or `import ./.` — the same **bare value**, not a
function, so it takes no dependency argument.

| Binding        | Signature                                                     |
| -------------- | ------------------------------------------------------------- |
| `hashIdentity` | `kind -> [label] -> (label -> value) -> "<kind>:<sha256hex>"` |

**That is the whole surface**, pinned by contents in `ci/tests/surface.nix`.

## When the encoder publishes

`canonicalEncode` has **zero callers** in the ecosystem and is deliberately internal. Its raw
signature is `depth -> budget -> value -> { s; b; }` — it publishes the THREADING PROTOCOL, and
handing a caller the budget hands it a second refusal policy over the same encoding, when the
bounds and the encoder are one mechanism rather than two.

When a consumer needs the encoding without a kind tag, it publishes **saturated**
(`value -> string`, the library's own bounds already applied) and under a **different name** —
so the threading protocol is never the published thing. It does not publish before there is a
caller to shape it.

## Traps

<!-- gen-citations:begin -->

| Trap                                                                                                                                                                                                                                                           | Evidence                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **The mint FORCES its input.** A lazily-failing leaf in a value fails at mint time, not at first read                                                                                                                                                          | `lib/default.nix`, binding `canonicalEncode`; the walk forces every node it encodes      |
| **`==`-equal int and float mint the SAME identity, and that is deliberate** — integral floats normalise to int. But the float domain is STRICT \`                                                                                                              | v                                                                                        |
| **A record whose `type` field merely holds the string `"derivation"` MINTS.** The gate tests the full three-attribute shape — `type` AND `drvPath` AND `outPath` — because testing `type` alone made admissibility depend on POSITION rather than on the value | `ci/tests/identity-encoding.nix`, `test-derivation-gate-does-not-depend-on-position`     |
| **A wide value is bounded by the LENGTH budget, not by a breadth bound.** Forcing both fold accumulator fields per step is what makes the budget bite on that axis; without it a 31,000-element list inside both declared bounds aborted uncatchably           | `lib/default.nix`, binding `encodeComposite`; `test-breadth-is-bounded-and-never-aborts` |
| **The depth bound's margin is ~6×, not an order of magnitude**, and the binding guard is Nix's `max-call-depth` (10,000), not a raw C stack — roughly 3 call frames per level                                                                                  | `lib/default.nix`, the two-bounds comment block                                          |
| **A cycle is caught by the DEPTH bound alone.** Its length crossover sits above the call-depth guard, so no budget setting exists at which length saves it                                                                                                     | `ci/tests/identity-encoding.nix`, `test-depth-bound-straddles-its-boundary`              |
| **The purity scan forbids substrate identifiers too**, not only nixpkgs tokens — and `stripComments` is load-bearing, not a courtesy: the word "merges" in correct English prose is a `merge` substring hit                                                    | `ci/tests/purity.nix`, and its two controls                                              |

<!-- gen-citations:end -->

## Checked invariants

- **Dependency-free**, over `lib/**.nix` + root `flake.nix` + `default.nix`: no nixpkgs tether,
  no module-system tier, and **no substrate identifier**. Two controls keep the scan honest —
  one asserting the sources are non-empty, one asserting the predicate is live on both halves.
- **Sole export**, pinned by contents, with a control naming each internal individually so a
  future export fails at the surface pin rather than silently widening the contract.

## Theory

ADR-0016 ruling 4 (the `==` biconditional in both directions, the strict float domain,
integral-float normalisation) · ADR-0016 ruling 5 (one minting authority; the substrate refuses
rather than inventing an identity) · ADR-0034 (identity is structural through the mint; the
domain is inert structure; what cannot be encoded gets no identity at all). The design of record
for `lib/default.nix`'s commentary is the closure-identity spec.

## Drift check

From the repository root:

```sh
nix eval --json .#lib --apply builtins.attrNames
```

Current output (verbatim):

```json
["hashIdentity"]
```

A one-name list is the claim rather than a truncated check. `canonicalEncode` and the bounds
beneath it are internal **by decision** (see *When the encoder publishes*), and
`ci/tests/surface.nix` pins the surface by contents — so a second name appearing in this block is
the drift, not the fix.
