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
      # `nix flake check` forces the WHNF of every top-level output and nothing deeper, so this root's
      # green quantified over the `lib` SPINE alone: a member of the published surface could throw and
      # the check still exited 0 (measured — den-hoag-z1ta6). Hanging the force on that spine is what
      # makes the green mean "the surface evaluates", and a library needs no new output name for it.
      # The depth is each member's WHNF and no deeper: a retirement tombstone is a published `throw`
      # by design (gen-scope's `buildNodes`), so a deep force is red on a healthy tree.
      lib =
        let
          surface = import ./lib;
        in
        builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) surface) surface;
    };
}
