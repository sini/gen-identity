# THE SECOND TEST OUTPUT — cells whose subject is WHICH refusal fired, not that one did.
#
# `builtins.tryEval` discards the message, so a `refuses` cell under ./tests pins only that a
# refusal happened. These cells pin the message, and a throwing `expr` cannot live under ./tests:
# `mkCi`'s `checks.default` asserter forces every cell's `expr` there and would crash, not fail.
# Same wiring as gen-schema's, gen-merge's and gen-memo's, through `mkCi`'s `extraModules`.
#
#   nix-unit --flake ./ci#testsError
#
# The two positions a caller supplies as STRUCTURE — the kind and the labels — are type-guarded
# before any builtin sees them, because a builtin's own type failure (`match`, `listToAttrs`)
# escapes `tryEval` and aborts the evaluation (ADR-0016 ruling 4, ADR-0025 item 1).
{ genIdentity, ... }:
let
  inherit (genIdentity) hashIdentity;
in
{
  flake.testsError.structural-refusals = {
    test-non-string-kind-refused-by-name = {
      expr = hashIdentity 1 [ "a" ] (_: 1);
      expectedError = {
        type = "ThrownError";
        msg = "^identity: a int as the relation kind; a kind is a string$";
      };
    };

    # The offending label is the SECOND, so a guard that checked only the head would let it through.
    test-non-string-label-refused-by-name = {
      expr = hashIdentity "k" [
        "a"
        { outPath = "x"; }
      ] (_: 1);
      expectedError = {
        type = "ThrownError";
        msg = "^identity: a set as an identity-key label; a label is a string; kind \"k\"$";
      };
    };
  };
}
