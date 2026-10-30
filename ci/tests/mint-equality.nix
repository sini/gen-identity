# BYTE EQUALITY WITH THE REFERENCE ENCODER — the library's `hashIdentity` against the budget-threaded
# encoder kept verbatim in `ci/mint-reference/reference.nix`.
#
# The library builds its preimage with the budget CHECKED rather than threaded, and that is admissible
# only because the preimage is byte-identical: every digest, and so every identity and every verdict
# downstream, is unchanged. These cells are that claim measured, on two populations:
#
# - THE CORPUS (`ci/mint-reference/corpus.json`): 94 distinct (kind, preimage) pairs traced from real
#   mints — gen-schema's kind marks and witnesses, gen-algebra's component tags, gen-types' type
#   identities — decoded back to inert values, each with the digest the threaded encoder minted for it.
#   A row must mint the same identity under the library, under the reference, and as recorded.
# - THE EDGE DOMAIN: escapes, unicode, the float bound pair, ±0.0, empties, an `outPath` record, a
#   context string, each bound straddled (chain, shared DAG, breadth, the outer frame's budget across
#   two labels) and every refused type. A row must mint the same identity under both, or be refused by
#   both.
#
# The counts are pinned beside the empty disagreement lists, so a corpus that failed to load or an
# edge set that minted nothing cannot pass as zero disagreements.
{ genIdentity, ... }:
let
  reference = import ../mint-reference/reference.nix;
  corpus = builtins.fromJSON (builtins.readFile ../mint-reference/corpus.json);

  remint = mint: c: mint.hashIdentity c.kind c.labels (l: c.values.${l});

  corpusMismatches = builtins.filter (i: i != null) (
    builtins.genList (
      i:
      let
        c = builtins.elemAt corpus i;
        lean = remint genIdentity c;
      in
      if lean == remint reference c && lean == "${c.kind}:${c.digest}" then null else i
    ) (builtins.length corpus)
  );

  chain = n: if n == 0 then null else { c = chain (n - 1); };
  dag =
    n:
    if n == 0 then
      "x"
    else
      let
        s = dag (n - 1);
      in
      [
        s
        s
      ];

  rows = {
    str = "a";
    strEsc = "q\"b\\s\nnl\ttab\u0001";
    unicode = "é😀";
    emptyStr = "";
    int = 42;
    negInt = -7;
    bigInt = 9223372036854775807;
    floatIntegral = 1.0;
    floatFrac = 1.5;
    floatSmall = 1.0e-7;
    floatNegZero = -0.0;
    floatNearBound = 9007199254740991.0;
    floatAtBound = 9007199254740992.0;
    t = true;
    f = false;
    nul = null;
    emptyList = [ ];
    emptyAttrs = { };
    nested = {
      a = [
        1
        { b = "c"; }
      ];
      "k y" = {
        "é" = null;
      };
    };
    keysNeedingEscape = {
      "a\"b" = 1;
      "c:d" = 2;
      "" = 3;
    };
    lambda = x: x;
    lambdaDeep = {
      a = [ (x: x) ];
    };
    path = ./mint-equality.nix;
    drvShape = {
      type = "derivation";
      drvPath = "x";
      outPath = "y";
    };
    typeDerivationOnly = {
      type = "derivation";
      n = 1;
    };
    outPathRecord = {
      outPath = "x";
      a = 1;
    };
    context = "${builtins.toFile "mint-equality-ctx" "x"}-tail";
    chain510 = chain 510;
    chain515 = chain 515;
    dag8 = dag 8;
    dag20 = dag 20;
    wide31000 = builtins.genList (_: null) 31000;
    wide32763 = builtins.genList (_: null) 32763;
    wide32764 = builtins.genList (_: null) 32764;
    wideRecord = builtins.listToAttrs (
      builtins.genList (i: {
        name = "k${toString i}";
        value = i;
      }) 4000
    );
  };

  attempt =
    e:
    let
      r = builtins.tryEval e;
    in
    if r.success then r.value else null;

  # Each row's outcome under one mint: its identity, or null where the mint refused.
  edgeOf =
    mint:
    builtins.mapAttrs (_: v: attempt (mint.hashIdentity "edge" [ "v" ] (_: v))) rows
    // {
      twoLabels = attempt (
        mint.hashIdentity "edge" [ "b" "a" ] (
          l:
          {
            a = 1;
            b = "x";
          }
          .${l}
        )
      );
      twoLabelsSwapped = attempt (
        mint.hashIdentity "edge" [ "a" "b" ] (
          l:
          {
            a = 1;
            b = "x";
          }
          .${l}
        )
      );
      outerBudgetSecondLabel = attempt (
        mint.hashIdentity "edge" [ "a" "b" ] (
          l:
          {
            a = builtins.genList (_: null) 20000;
            b = builtins.genList (_: null) 20000;
          }
          .${l}
        )
      );
    };

  leanEdge = edgeOf genIdentity;
  referenceEdge = edgeOf reference;
in
{
  flake.tests.mint-equality = {
    test-corpus-mints-the-reference-and-recorded-identities = {
      expr = {
        rows = builtins.length corpus;
        mismatches = corpusMismatches;
      };
      expected = {
        rows = 94;
        mismatches = [ ];
      };
    };

    # 38 rows: 29 mint (28 distinct identities; the label-order pair shares one by construction) and 9
    # are refused by both — lambda, nested lambda, path, derivation shape, the float at the bound,
    # chain 515, DAG 20, wide 32,764 and the outer frame's budget crossed at its second label.
    test-edge-domain-agrees-with-the-reference = {
      expr = {
        rows = builtins.length (builtins.attrNames leanEdge);
        refused = builtins.length (builtins.filter (v: v == null) (builtins.attrValues leanEdge));
        disagreements = builtins.filter (k: leanEdge.${k} != referenceEdge.${k}) (
          builtins.attrNames leanEdge
        );
      };
      expected = {
        rows = 38;
        refused = 9;
        disagreements = [ ];
      };
    };
  };
}
