# gen-identity REPL — the mint in scope. Run: nix repl --impure --file ci/repl.nix
#
# gen-identity has no dependencies; nixpkgs `lib` is exposed only for interactive convenience
# and is not a library dependency — `ci/tests/purity.nix` is what keeps that true of ../lib.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;
  genIdentity = import ../lib;
in
{
  inherit lib genIdentity;
  inherit (genIdentity) hashIdentity;
}
