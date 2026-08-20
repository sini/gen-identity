# gen-identity — agent cheatsheet

## Scope

The gen ecosystem's **one minting authority**. `hashIdentity` turns a kind tag, a label list and
a value lookup into `"<kind>:<sha256hex>"`, over a bounded type-tagged canonical encoding of
inert Nix values. Nothing else in the ecosystem mints (ADR-0016 ruling 5).

Zero dependencies of any kind. `lib` is a bare attrset, not a function.

## Not this library's job

| Need                                                                                                   | Owner                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Which of a kind's declared options are identity KEYS; recomputing an instance hash; stamping `id_hash` | `gen-schema` — the identity **reflection** half. It reads option metadata and builds options with the module system; it calls this library and does not belong to it |
| Intensional function identity and conservative equality                                                | `gen-algebra`                                                                                                                                                        |
| Structural type checking                                                                               | `gen-types`                                                                                                                                                          |
| General pure utilities                                                                                 | `gen-prelude`                                                                                                                                                        |
| Digest / dedup keys that want a canonical encoding and explicitly NOT a kind-tagged identity           | Not served yet — see *When the encoder publishes* below                                                                                                              |

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

| Trap                                                                                                                                                                                                                                                           | Evidence                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **The mint FORCES its input.** A lazily-failing leaf in a value fails at mint time, not at first read                                                                                                                                                          | `lib/default.nix`, binding `canonicalEncode`; the walk forces every node it encodes      |
| **`==`-equal int and float mint the SAME identity, and that is deliberate** — integral floats normalise to int. But the float domain is STRICT \`                                                                                                              | v                                                                                        |
| **A record whose `type` field merely holds the string `"derivation"` MINTS.** The gate tests the full three-attribute shape — `type` AND `drvPath` AND `outPath` — because testing `type` alone made admissibility depend on POSITION rather than on the value | `ci/tests/identity-encoding.nix`, `test-derivation-gate-does-not-depend-on-position`     |
| **A wide value is bounded by the LENGTH budget, not by a breadth bound.** Forcing both fold accumulator fields per step is what makes the budget bite on that axis; without it a 31,000-element list inside both declared bounds aborted uncatchably           | `lib/default.nix`, binding `encodeComposite`; `test-breadth-is-bounded-and-never-aborts` |
| **The depth bound's margin is ~6×, not an order of magnitude**, and the binding guard is Nix's `max-call-depth` (10,000), not a raw C stack — roughly 3 call frames per level                                                                                  | `lib/default.nix`, the two-bounds comment block                                          |
| **A cycle is caught by the DEPTH bound alone.** Its length crossover sits above the call-depth guard, so no budget setting exists at which length saves it                                                                                                     | `ci/tests/identity-encoding.nix`, `test-depth-bound-straddles-its-boundary`              |
| **The purity scan forbids substrate identifiers too**, not only nixpkgs tokens — and `stripComments` is load-bearing, not a courtesy: the word "merges" in correct English prose is a `merge` substring hit                                                    | `ci/tests/purity.nix`, and its two controls                                              |

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
