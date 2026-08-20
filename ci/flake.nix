{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    # nixpkgs is the CI runner's dependency (test harness, treefmt) and supplies the `lib`
    # the test modules use — including the scan in ci/tests/purity.nix. gen-identity itself
    # (../lib) takes no inputs, which is the property that scan exists to keep true.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen-harness, ... }:
    let
      genIdentity = import ../lib;
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-identity";
      testModules = ./tests;
      specialArgs = { inherit genIdentity; };
    };
}
