# gen-identity — the substrate's one identity mint

`hashIdentity` is the one minting authority for the gen ecosystem; nothing else mints.
An identity is a kind tag joined to a digest of the ⟨label, value⟩ pairs:

```
identity = "<kind>:" + sha256(<pairs preimage>)
```

and the preimage is produced by a **bounded, type-tagged canonical encoding** of inert Nix
values. What cannot be encoded totally gets no identity at all and is **refused by name**.

Zero dependencies — not nixpkgs, not any gen substrate. The `lib` output is a bare attrset.

## Usage

```nix
{
  inputs.gen-identity.url = "github:sini/gen-identity";

  outputs = { gen-identity, ... }:
    let inherit (gen-identity.lib) hashIdentity; in
    {
      # kind -> [label] -> (label -> value) -> "<kind>:<sha256hex>"
      id = hashIdentity "host" [ "name" "system" ] (k: { name = "igloo"; system = "x86_64-linux"; }.${k});
      # → "host:9d5cc671…"
    };
}
```

Without flakes: `import ./path/to/gen-identity` is a nullary function over the lib value —
`import ./path/to/gen-identity { }`.

## The surface

**One binding publishes.** `hashIdentity`. The encoder beneath it — `canonicalEncode`,
`canonicalPreimage`, `emit`, `encodeComposite`, `encodeField` — and its bound constants stay
internal, and that is a decision rather than an omission: the raw encoder's signature threads a
budget, so publishing it would hand a caller a second refusal policy over the same encoding,
and the bounds and the encoder are one mechanism rather than two. `ci/tests/surface.nix` pins
this by contents.

## What enters the mint, and what is refused

**Admitted** — strings, bools, ints, in-range floats, `null`, and lists and attrsets of them,
to any depth the bounds allow. Structure is **emitted, never delegated**: `builtins.toJSON` is
not structure-preserving on attrsets (a record carrying `outPath` renders as that string alone,
discarding every sibling), so the encoder emits structure itself and applies `toJSON` only to
strings. Every node carries a **type tag**, which is what makes forgery inexpressible rather
than blocked case by case — a string can never render as a list, because its rendering begins
`s`.

**Refused by name** — a lambda (no builtin exposes a closure's captured environment or its
body, so no preimage over one can be total), a path (`toJSON` on a file path silently copies it
to the store), a derivation (its output attribute is self-referential, so an unbounded walk does
not terminate), a float outside `|v| < 2^53`, a non-string or empty kind, a kind containing `:`,
zero labels, a non-string label, and a duplicate label. A refusal raised after the kind passes
its guards names the kind, and inside a label's walk the label too
(`identity: a lambda in an identity position; kind "attaches", label "entity"`). It never
renders the rejected value, so describing a refusal reads no caller data; `--show-trace`
locates the position inside the value.

**Bounded on three axes.** Preimage LENGTH and walk DEPTH are declared bounds; BREADTH is
answered by forcing both fold accumulator fields at every step, which is what makes the length
budget bite on that axis at all. Exhausting any of them is a refusal by name, never an abort.

## Testing

```bash
nix develop ./ci --command ci                # the suites, guarded
nix develop ./ci --command ci --tests-error  # the error-plane cells, guarded
nix repl --impure --file ci/repl.nix
```

`ci` refuses when anything under a declared read root is unknown to git — any extension or name,
`_`-prefixed included — and the remedy is `git add` or a move. The bare `nix-unit --flake ./ci#tests`
and `nix flake check ./ci` are unguarded: they read a git-filtered copy of the tree, so an untracked
cell is silently absent and the run stays green.

75 cells across five suites: `identity-encoding` (the laws, the domain, the forgery arms, both
boundary straddles), `purity` (the dependency-free invariant, with its two controls),
`string-context`, `surface` (the export pin), and `refusal-attribution` (golden digests over
hand-written preimages, and catchability). `testsError` holds 12 more that pin a refusal's
message: 2 in `ci/tests-error.nix` and 10 in `ci/tests/refusal-attribution.nix`.

## Theory

The encoding follows the language's `==` in **both directions** — neither coarser nor finer —
over the whole admitted domain. That biconditional, the strict float bound and integral-float
normalisation are the mint's original terms; the domain extension to inert composites, the
type tags and the bounded walk came later, when identity was made structural. The reasoning
behind every sentence of `lib/default.nix`'s commentary was settled before the code landed,
and the commentary travelled with the code when the mint moved here from gen-schema, because
a comment block belongs to the code it documents.

## Gen Ecosystem

| Library                                              | Role                                                                                                                              |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [gen-identity](https://github.com/sini/gen-identity) | **This lib** — the one identity mint: a bounded canonical encoding and the kind-tagged digest over it                             |
| [gen-prelude](https://github.com/sini/gen-prelude)   | Pure nixpkgs-lib-free utility base                                                                                                |
| [gen-schema](https://github.com/sini/gen-schema)     | Typed record registry — and the identity **reflection** half: which of a kind's options are identity keys, and stamping `id_hash` |
| [gen-types](https://github.com/sini/gen-types)       | Pure structural type checker                                                                                                      |
| [gen-algebra](https://github.com/sini/gen-algebra)   | Records, intensional functions, either                                                                                            |
