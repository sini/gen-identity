# Purity invariant: gen-identity's library source depends on NOTHING — not nixpkgs, and not any
# gen substrate. This pins "dependency-free" as a checked property rather than an aspiration.
#
# ★★ THE PREDICATE IS STRICTER THAN EVERY SIBLING'S, AND THE EXTRA HALF IS THE POINT. The sibling
# scans forbid `nixpkgs`, `lib.`, `{ lib }`, `evalModules`, `mkOption` — a NIXPKGS-LIB-FREE claim.
# This library claims something stronger: it has no dependency of any kind, which is what lets a
# library upstream of gen-schema reach the one minting authority without closing a flake cycle.
# A scan checking only the weaker claim would go green on a library that had quietly grown a
# `{ prelude }` parameter, and the whole reason this library exists would have leaked away
# without a red. So every substrate identifier is forbidden too.
#
# ★★ AND `stripComments` IS LOAD-BEARING HERE RATHER THAN A COURTESY TO DOCUMENTATION — measured.
# The forbidden list contains ordinary English words and this library's source is roughly 60%
# prose. Over the moved span alone: raw ⇒ ONE `merge` hit, comment-stripped ⇒ ZERO. The hit is the
# word "merges" in a correct English sentence — "an identity minted over a partial preimage
# MERGES behaviourally distinct values" — caught because the scan is a substring test and `merge`
# is a substring of `merges`. Without inherited comment-stripping this oracle reds on the
# library's own shipped commentary, on day one, for a sentence that is true. A purity scan that
# fails on true prose gets weakened by whoever meets it next, and the weakening lands on the
# token list rather than on the predicate.
#
# Scope: lib/**.nix + the root flake.nix + default.nix (the library and its entries). NOT ci/ —
# the test harness legitimately uses the nixpkgs lib, including to run this scan.
{ lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here because
  # `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # Recursive walk, so the scan keeps covering `lib/` if the library ever grows past one file.
  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  # A nixpkgs-lib tether or the module-system tier — the sibling half of the scan.
  forbiddenNixpkgs = [
    "nixpkgs" # a nixpkgs flake input / reference
    "lib." # any nixpkgs lib call (lib.types, lib.genAttrs, …)
    "{ lib }" # the `{ lib }` parameter signature
    "{ lib," # `{ lib, … }` parameter signature
    "evalModules" # module-system tier
    "mkOption" # module-system tier
  ];

  # Every substrate identifier, by the ecosystem's own injection convention: a gen library
  # arrives under its name minus `gen-`. Any of these appearing in the library's code means a
  # dependency has been taken, whatever the flake says.
  forbiddenSubstrate = [
    "prelude"
    "merge"
    "algebra"
    "schema"
    "scope"
    "graph"
    "aspects"
    "types"
  ];

  forbidden = forbiddenNixpkgs ++ forbiddenSubstrate;

  violations = lib.concatMap (
    src: map (tok: "${src.name}: '${tok}'") (lib.filter (tok: lib.hasInfix tok src.code) forbidden)
  ) sources;

  # Positive control for the scan itself: the same predicate, in the same run, over a string that
  # DOES contain forbidden tokens — one from each half, so neither half can be silently dead. An
  # empty `violations` above is evidence only if this is non-empty; otherwise a broken `hasInfix`
  # or an empty `sources` would report clean.
  controlViolations = lib.filter (
    tok: lib.hasInfix tok "let x = evalModules { }; y = prelude.foo; in x"
  ) forbidden;
in
{
  flake.tests.purity = {
    test-library-source-is-dependency-free = {
      expr = violations;
      expected = [ ];
    };

    # The scan reaches real files with real content. A vacuous `sources` — an empty lib/, a
    # readDir that found nothing — would report the invariant clean without testing it, so the
    # non-emptiness is asserted rather than assumed.
    test-control-scan-reads-non-empty-sources = {
      expr = sources != [ ] && lib.all (s: s.code != "") sources;
      expected = true;
    };

    # The forbidden-token scan is LIVE, and both halves of it are. A run in which this is empty
    # has not tested the invariant above — it has tested a dead predicate.
    test-control-forbidden-token-scan-is-live = {
      expr = lib.sort (a: b: a < b) controlViolations;
      expected = [
        "evalModules"
        "prelude"
      ];
    };
  };
}
