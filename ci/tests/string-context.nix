# String CONTEXT is not identity-bearing, at every position the mint takes a string.
#
# ADR-0016 ruling 4 (identity follows Nix `==`, in both directions), inherited by ADR-0034 over the
# whole admitted domain: a context-carrying string and its context-free twin are `==`, so they mint
# ONE identity, and no minted identity carries context. One cell per position — VALUE, KIND, LABEL —
# each with its own controls: the fixture carries context, the twins are `==`, and the comparator
# separates distinct inputs. The fixture is a derivation's string form, the same shape as
# identity-encoding.nix's `realDerivation`; the derivation itself stays refused by type test.
#
# A NON-STRING label is not a context question: it is refused by name before any discard can coerce
# it (`{ outPath = "x"; }` would otherwise read as "x"). That refusal's message is pinned in
# ../tests-error.nix, because a throwing `expr` cannot live under ./tests.
{
  genIdentity,
  ...
}:
let
  inherit (genIdentity) hashIdentity;
  admits = e: (builtins.tryEval (builtins.deepSeq e e)).success;
  idOf = v: hashIdentity "k" [ "x" ] (_: v);
  drv = derivation {
    name = "identity-context-probe";
    system = "x86_64-linux";
    builder = "/bin/sh";
  };
  # A context-carrying string and its context-free twin. `==` holds between them.
  ctx = "${drv}";
  plain = builtins.unsafeDiscardStringContext ctx;
  # An EMPTY string carrying the same context, for positions where the TEXT must stay fixed.
  z = builtins.substring 0 0 ctx;
in
{
  # VALUE position — the digest is context-free (`hashString` returns a fresh string).
  flake.tests.string-context.test-value-context-is-not-identity = {
    expr = {
      controlFixtureCarriesContext = builtins.hasContext ctx;
      controlTwinsAreEqual = ctx == plain;
      sameIdentity = idOf ctx == idOf plain;
      nestedSameIdentity = idOf { a = [ ctx ]; } == idOf { a = [ plain ]; };
      identityCarriesNoContext = !(builtins.hasContext (idOf ctx));
      # CONTROL: the comparator can tell identities apart.
      controlSeparates = idOf "a" != idOf "b";
    };
    expected = {
      controlFixtureCarriesContext = true;
      controlTwinsAreEqual = true;
      sameIdentity = true;
      nestedSameIdentity = true;
      identityCarriesNoContext = true;
      controlSeparates = true;
    };
  };

  # KIND position — the kind rides OUTSIDE the digest, so its context would reach the identity string.
  flake.tests.string-context.test-kind-context-does-not-reach-the-identity = {
    expr =
      let
        i = hashIdentity "k${z}" [ "x" ] (_: "a");
      in
      {
        controlKindCarriesContext = builtins.hasContext "k${z}";
        sameIdentity = i == hashIdentity "k" [ "x" ] (_: "a");
        identityCarriesNoContext = !(builtins.hasContext i);
      };
    expected = {
      controlKindCarriesContext = true;
      sameIdentity = true;
      identityCarriesNoContext = true;
    };
  };

  # LABEL position — an identity-key name carrying context; `listToAttrs` aborts uncatchably on one.
  flake.tests.string-context.test-label-context-mints-not-aborts = {
    expr = {
      mints = admits (hashIdentity "k" [ "x${z}" ] (_: "a"));
      sameIdentity = hashIdentity "k" [ "x${z}" ] (_: "a") == hashIdentity "k" [ "x" ] (_: "a");
      # `==`-equal labels ARE duplicates, and are refused by name as any duplicate is.
      contextOnlyDuplicateRefused = !(admits (hashIdentity "k" [ "x" "x${z}" ] (_: "a")));
    };
    expected = {
      mints = true;
      sameIdentity = true;
      contextOnlyDuplicateRefused = true;
    };
  };
}
