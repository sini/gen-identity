{
  description = "gen-identity: the substrate's one identity mint — a bounded canonical encoding of inert values and the kind-tagged digest over it";

  # NO inputs, and unlike gen-assemble and gen-program this is not "the substrate arrives
  # injected" — there IS no substrate. The mint is builtins and nothing else, measured: the
  # content evaluates with every argument poisoned, and ci/tests/purity.nix scans for every
  # substrate identifier rather than only for a nixpkgs tether. gen-prelude ships this same
  # shape; the test runner lives in ./ci, a separate flake.
  outputs =
    { ... }:
    {
      lib = import ./lib;
    };
}
