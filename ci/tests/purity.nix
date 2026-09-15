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
# prose, so the raw text trips the scan in several places while the CODE trips it nowhere.
#
# Measured over `lib/default.nix` as shipped: RAW ⇒ SEVEN hits across FIVE forbidden tokens;
# comment-stripped ⇒ ZERO across all fourteen. The seven:
#
#   `merge`   — "an identity minted over a partial preimage MERGES behaviourally distinct values",
#               a substring hit on a correct English sentence
#   `graph`   — inside the word "crypto-GRAPH-ic", which is not even a word about a dependency
#   `schema`  — ×3, this file's own header explaining that the reflection half stays in gen-schema
#   `types`   — "gen-types cannot reach gen-schema without closing a flake cycle", the sentence
#               that states WHY this library exists
#   `nixpkgs` — the header sentence describing this very scan
#
# ★ THE LAST THREE ARE THE STRONGER ARGUMENT, because they are not accidents of substring
# matching: a library whose whole reason for existing is WHERE IT SITS RELATIVE TO OTHER
# LIBRARIES cannot document itself without naming them. Without inherited comment-stripping this
# oracle reds on the library's own explanation of itself, on day one, for prose that is true. A
# purity scan that fails on true prose gets weakened by whoever meets it next, and the weakening
# lands on the token list rather than on the predicate — which is how a scan quietly stops
# checking the thing it was written for.
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

  # ★ THE STRIP'S PREMISE, asserted rather than assumed. `stripComments` cuts each line at a comment
  # marker, and that cut is sound only while the `#` it cuts at stands OUTSIDE a string literal.
  # Where it does not, live code is truncated to the end of that line and every cell below goes
  # blind on what was removed, with no signal at all — a green suite over source nothing scanned.
  #
  # The predicate asks the strip ITSELF where it cut: `stripComments` of a single line is exactly
  # the text before that line's cut. It then asks whether that text closed every double quote it
  # opened, an odd count meaning the cut stands inside a string. Deriving it from `stripComments`
  # rather than restating the cut rule is what keeps premise and strip from drifting apart when one
  # of them is edited, and it is why one block serves both strip families in this ecosystem.
  #
  # It is LINE-LOCAL and so cannot conclude about string content that spans lines — an indented
  # multi-line string block. Those files are declared as a list of their own by
  # `test-strip-premise-multiline-strings` rather than trusted in silence.
  countQuotes = s: (lib.length (lib.splitString "\"" s)) - 1;
  cutIsInString =
    line:
    let
      kept = stripComments line;
    in
    kept != line && lib.mod (countQuotes kept) 2 == 1;

  # premiseBreaches : [ { name; text; } ] -> [ "file:line" ]. A breach is reported at its line as
  # well as its file, because what it says is that one particular line's code was truncated.
  premiseBreaches =
    srcs:
    lib.concatMap (
      src:
      lib.concatLists (
        lib.imap1 (i: line: lib.optional (cutIsInString line) "${src.name}:${toString i}") (
          lib.splitString "\n" src.text
        )
      )
    ) srcs;

  # Recursive walk, so the scan keeps covering `lib/` if the library ever grows past one file.
  # walk : string -> path -> [ { name; path; } ], `name` being `prefix` extended by the entry's
  # position in the tree. The label a red CI prints is the whole product of a failing cell, and a
  # `toString` of the path value renders the store copy the flake is evaluated from
  # (`/nix/store/<hash>-source/lib/default.nix`) — a file no reader can open in their own checkout,
  # whose hash moves on any unrelated edit. Same shape as gen-link's and gen-graph's, deliberately.
  walk =
    prefix: dir:
    lib.concatLists (
      lib.mapAttrsToList (
        entry: type:
        if type == "directory" then
          walk "${prefix}${entry}/" (dir + "/${entry}")
        else if lib.hasSuffix ".nix" entry then
          [
            {
              name = "${prefix}${entry}";
              path = dir + "/${entry}";
            }
          ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  # ★ THE READ AND THE STRIP ARE SEPARATE STAGES, one `readFile` per file feeding both. The premise
  # cell has to speak about the RAW text, which is only a value once the strip stops happening inside
  # the read; and `sources` is then a total per-element function of `rawSources` — the name passes
  # through, the code is the strip of the text — so pinning either one pins the other, and the cells
  # over each COMPOSE instead of hoping two independent reads of the same tree agree.
  raw =
    entries:
    map (e: {
      inherit (e) name;
      text = builtins.readFile e.path;
    }) entries;

  strip =
    entries:
    map (e: {
      inherit (e) name;
      code = stripComments e.text;
    }) entries;

  rawSources = raw (walk "lib/" libDir) ++ [
    {
      name = "flake.nix";
      text = builtins.readFile ../../flake.nix;
    }
    {
      name = "default.nix";
      text = builtins.readFile ../../default.nix;
    }
  ];

  sources = strip rawSources;

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

  # The live counterpart to `forbidden`: the name this library reaches for where a tether would reach
  # for a substrate. `builtins` is not merely present, it is the WHOLE of what this library is allowed
  # to name — the mint is builtins and nothing else — so it is the exact dual of the two forbidden
  # halves above. Every gen-identity source but ONE carries it, and that exclusion is the root
  # `default.nix`, whose entire body is `{ }: import ./lib` and which therefore names no builtin. That
  # exclusion is what gives the assertion its teeth: the expected list is a PROPER SUBSET of the
  # manifest, so a read returning one fixed text for every file lands outside it either way — without
  # the token the list collapses toward empty, with it the list swells to every source.
  liveToken = "builtins";
  liveReads = map (src: src.name) (lib.filter (src: lib.hasInfix liveToken src.code) sources);

  # scan : [ { name; code; } ] -> [ "file: 'tok'" ]. Factored out of `violations` so the detector
  # cell below runs THE SAME call over the same source list with one entry appended, rather than a
  # second copy of the predicate that could drift from this one.
  scan =
    srcs:
    lib.concatMap (
      src: map (tok: "${src.name}: '${tok}'") (lib.filter (tok: lib.hasInfix tok src.code) forbidden)
    ) srcs;

  violations = scan sources;

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

    # What the cell above is a statement ABOUT. Its `[ ]` is produced just as readily by a scan that
    # reads the wrong tree, or no tree, as by a library that is dependency-free, and neither the
    # controls below nor a guard on the source list's SIZE can tell those apart — the first speak
    # about a planted literal, and the second answers a question about how many rather than which.
    # Disconnection is an IDENTITY defect: a scan that had dropped the library file and kept only the
    # two root entries is non-empty, has non-empty content, and reports the invariant clean over a set
    # containing none of the library. So membership is written down as the label list itself.
    # Asserting the list also makes a second library module arrive as a RED rather than being absorbed
    # silently, which is the point — the scope of an invariant is a declared surface, not a default,
    # and for THIS library the surface is the whole of the claim: *dependency-free* is a statement
    # about a named set of files, not about however many a walk happened to find.
    test-scan-subject-is-the-library-tree = {
      expr = map (s: s.name) sources;
      expected = [
        "lib/default.nix"
        "flake.nix"
        "default.nix"
      ];
    };

    # And that those labels carry their files' text. The manifest above pins membership and is silent
    # on content: a read that handed every entry one fixed string would satisfy it exactly, and a live
    # `prelude.foo` sitting in the real library file would pass through all of the other cells here at
    # exit 0. This is the same shape as the manifest — an exact list, not a count — asked of a token
    # that is genuinely present rather than genuinely absent, so the reads are shown to carry this
    # repository's source and not a constant.
    test-scan-reads-are-live = {
      expr = liveReads;
      expected = [
        "lib/default.nix"
        "flake.nix"
      ];
    };

    # The residual content floor for the one label the live list cannot reach. `sources != [ ]` is
    # this cell's own vacuity guard — `all` over an empty list is true — and it is a floor, NOT a
    # subject pin: a non-empty constant substituted for a source passes it exactly as the real text
    # does, which is why the two cells above exist rather than this one carrying the subject.
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

    # ★ THE PREMISE HOLDS OF THE TEXT THAT WAS ACTUALLY SCANNED. This is an absence claim over text
    # read from disk and it is NOT non-vacuous on its own: its expectation is `[ ]`, which an emptied
    # or constant subject satisfies exactly as a sound corpus does — a scan of nothing breaches no
    # premise. What arms it is the subject-pinning asserted over this same `rawSources` read, together
    # with the live control below for the predicate itself; green here means the premise holds of the
    # text those cells pin, and nothing more.
    test-strip-premise-holds = {
      expr = premiseBreaches rawSources;
      expected = [ ];
    };

    # And the predicate is capable of saying no. Its subject is a literal written inside this cell
    # rather than anything on disk, so it is UNSEVERABLE from the tree and establishes exactly that the
    # test discriminates an in-string `#` from an ordinary trailing comment — it says nothing whatever
    # about what the cell above was pointed at, and it is NOT that cell's arming. Both directions ride
    # in one expectation: line 1 must be caught and line 2 must not, so a predicate stuck at either
    # constant reds here. The literal cuts under BOTH strip families in this ecosystem — its `#` is
    # whitespace-preceded, so a comment-start strip cuts there too and the control cannot go dead by
    # being pasted into a repository whose strip is the other one.
    test-strip-premise-scan-is-live = {
      expr = premiseBreaches [
        {
          name = "<in-string-hash>";
          text = ''
            url = "a b # c";
            x = 1; # an ordinary trailing comment
          '';
        }
      ];
      expected = [ "<in-string-hash>:1" ];
    };

    # The declared surface: the files the line-local predicate cannot conclude about. An indented
    # multi-line string block carries string content across line boundaries, where a per-line quote
    # count cannot follow it, so those files are written down rather than trusted in silence. The first
    # file to grow one arrives as a red that has to be READ, exactly as a new library file arrives as a
    # red on a membership manifest.
    test-strip-premise-multiline-strings = {
      expr = map (s: s.name) (lib.filter (s: lib.hasInfix "''" s.text) rawSources);
      expected = [ ];
    };
  };
}
