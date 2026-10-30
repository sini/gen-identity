# The EXPORT SURFACE, pinned by contents.
#
# ★ ONE BINDING PUBLISHES: `hashIdentity`. The encoder beneath it — `mkEncoder` and its `enc`
# and `field`, `canonicalPreimage`, `frameOf`, `dupOf` — and its bound constants
# stay INTERNAL, and that is a decision with a reason rather than an omission.
#
# The raw encoder's signature is `depth -> budget -> value -> string`: it publishes the
# BUDGET PROTOCOL. Handing a caller the budget parameter hands it a second refusal policy over
# the same encoding, and the design's whole domain argument is that the bounds and the encoder are
# ONE mechanism and not two — the composite fold that charges each member is what makes the budget
# bite at all. A published budget reintroduces exactly that seam.
#
# No oracle is lost by declining: every cell in `identity-encoding.nix` reaches the encoder
# through `hashIdentity`, directly or through the file's own `idOf` / `admits` / `refuses`
# helpers, each defined in terms of it. Every bound, every named refusal, both boundary straddles
# and the forgery arms are all reachable from the published binding alone.
#
# When a consumer needs the encoding without a kind tag — the digest and dedup-key sites that
# want a canonical encoding and explicitly NOT an identity — it publishes SATURATED
# (`value -> string`, the library's own bounds already applied) and under a DIFFERENT NAME, so
# the budget protocol is never the published thing. It does not publish before there is a
# caller to shape it.
{ genIdentity, ... }:
{
  flake.tests.surface = {
    # Pinned by CONTENTS, not by count: a count is satisfied by swapping one export for another.
    test-exports-exactly-hashIdentity = {
      expr = builtins.attrNames genIdentity;
      expected = [ "hashIdentity" ];
    };

    # The published binding is the mint, not an accidental attrset that happens to be named.
    test-hashIdentity-is-a-function = {
      expr = builtins.isFunction genIdentity.hashIdentity;
      expected = true;
    };

    # CONTROL: the internals really are absent rather than merely unlisted above. Named
    # individually so a future export of any one of them fails HERE, at the surface pin, rather
    # than silently widening the library's contract.
    test-control-encoder-internals-are-not-published = {
      expr = builtins.filter (n: genIdentity ? ${n}) [
        "mkEncoder"
        "enc"
        "field"
        "canonicalPreimage"
        "frameOf"
        "dupOf"
        "identityBudget"
        "identityDepth"
        "exactBound"
      ];
      expected = [ ];
    };
  };
}
