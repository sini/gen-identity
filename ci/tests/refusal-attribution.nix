# REFUSAL ATTRIBUTION — every mint refusal raised after the kind has passed its guards names the
# KIND and, inside a label's walk, the LABEL (ADR-0025 item 1's named refusal; ADR-0034's
# refuse-by-name). A refusal that says only what was rejected leaves a caller with several
# relata unable to tell which one is at fault. No subject is rendered for any type: a message
# reads the kind, the label and constant text only, because reading caller data (a derivation's
# `name`) can fail outside `tryEval` and turn a named refusal into an abort, and a path renders as
# a per-evaluation virtual store path under lazy trees. The position inside the value is not
# named; `--show-trace` locates it.
#
# Two planes, this suite's own wiring: `testsError` pins the message (anchored `^…$`), and
# `tests` pins that the attribution moved no identity and left every refusal catchable.
{ genIdentity, ... }:
let
  inherit (genIdentity) hashIdentity;
  attaches =
    relata:
    hashIdentity "attaches" [
      "aspect"
      "entity"
    ] (l: relata.${l});
  drv = derivation {
    name = "xvww";
    system = "x86_64-linux";
    builder = "/bin/sh";
  };
  # A derivation-shaped value whose `name` fails in a way `tryEval` does not contain.
  badDrv = {
    type = "derivation";
    drvPath = "x";
    outPath = "x";
    name = { x = 1; }.y;
  };
  deep = builtins.foldl' (acc: _: [ acc ]) 0 (builtins.genList (x: x) 600);
  longKind = builtins.concatStringsSep "" (builtins.genList (_: "k") 200);
in
{
  flake.testsError.mint-refusal-attribution = {
    test-nested-lambda-names-kind-and-label = {
      expr = attaches {
        aspect = "aspect:0";
        entity = {
          cfg.hooks = [
            1
            (x: x)
          ];
        };
      };
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: a lambda in an identity position; kind "attaches", label "entity"$'';
      };
    };
    test-path-names-kind-and-label-not-the-path = {
      expr = attaches {
        aspect = /tmp;
        entity = "host:0";
      };
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: a path in an identity position; kind "attaches", label "aspect"$'';
      };
    };
    test-derivation-names-kind-and-label-not-its-name = {
      expr = attaches {
        aspect = "aspect:0";
        entity = drv;
      };
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: a derivation in an identity position; kind "attaches", label "entity"$'';
      };
    };
    # The refusal reads nothing from the value, so a broken `name` cannot reach the message.
    test-derivation-with-broken-name-is-a-named-refusal = {
      expr = hashIdentity "k" [ "a" ] (_: badDrv);
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: a derivation in an identity position; kind "k", label "a"$'';
      };
    };
    test-float-names-kind-and-label = {
      expr = attaches {
        aspect = "aspect:0";
        entity = 1.0e300;
      };
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: float outside the exactly-representable integer range; kind "attaches", label "entity"$'';
      };
    };
    test-budget-names-kind-and-label = {
      expr = attaches {
        aspect = "aspect:0";
        entity = builtins.genList (_: null) 40000;
      };
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: preimage exceeds the identity budget; kind "attaches", label "entity"$'';
      };
    };
    test-depth-names-kind-and-label = {
      expr = attaches {
        aspect = "aspect:0";
        entity = deep;
      };
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: value nests deeper than the identity depth bound; kind "attaches", label "entity"$'';
      };
    };
    # No cap exists to cut the label off behind a long kind.
    test-depth-keeps-the-label-behind-a-long-kind = {
      expr = hashIdentity longKind [ "entity" ] (_: deep);
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: value nests deeper than the identity depth bound; kind "k+", label "entity"$'';
      };
    };
    test-duplicate-names-the-label-and-kind = {
      expr = hashIdentity "attaches" [
        "aspect"
        "aspect"
      ] (_: "x");
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: duplicate identity key "aspect"; kind "attaches"$'';
      };
    };
    test-zero-keys-names-kind = {
      expr = hashIdentity "attaches" [ ] (_: "x");
      expectedError = {
        type = "ThrownError";
        msg = ''^identity: zero identity keys; kind "attaches"$'';
      };
    };
  };

  flake.tests.mint-refusal-attribution = {
    # The attribution change must move NO identity. Each digest is sha256 over the HAND-WRITTEN
    # preimage beside it, computed with `printf '%s' '<preimage>' | sha256sum` from the encoder's
    # grammar and not read from the implementation. Preimage grammar: a record is `{` + per field
    # (JSON key `:` value `,`) + `}`; s = string (JSON), i = int, f = float, b0/b1 = bool, z = null.
    test-refusal-context-moves-no-identity = {
      expr = [
        # {"aspect":s"aspect:0","entity":s"host:0",}
        (attaches {
          aspect = "aspect:0";
          entity = "host:0";
        })
        # {"aspect":s"a","entity":{"we ird":{},"x":[i1,f2.5,z,b1,],},}
        (attaches {
          aspect = "a";
          entity = {
            x = [
              1
              2.5
              null
              true
            ];
            "we ird" = { };
          };
        })
        # {"aspect":s"a","entity":[i0,i1,…,i299,],}
        (attaches {
          aspect = "a";
          entity = builtins.genList (x: x) 300;
        })
        # {"a":b0,}
        (hashIdentity "k" [ "a" ] (_: false))
        # {"a":s"q\"\\\n\t",}   (the bytes: q, then backslash-escaped quote, backslash, n, t)
        (hashIdentity "k" [ "a" ] (_: "q\"\\\n\t"))
        # {"a":i-7,}
        (hashIdentity "k" [ "a" ] (_: -7))
      ];
      expected = [
        "attaches:b9cf97e8e3fde91902a9f12a8be53dc38a2398914c9db0887d704364924874ef"
        "attaches:b2728dbb91964603dec7a041888ca1c448b5746765e85cd0921900c0d441d993"
        "attaches:d5b74ac29edd67f49abd4fea8c905c93a5a41b2a4d32a52b2fce2a01c879fe36"
        "k:0e88a58193bbea5e3049945295747e76ead67852e0e87c4ec571e7a5cc90bf67"
        "k:352c7e46baa0943ffc511faa0ed7e9ad812aa9ecadead50bd7601de8efa68103"
        "k:6b5a6205840b08b2f0522b7085c5bafe488166bc8c065890833d5166e02ca2d7"
      ];
    };
    # Still catchable: the attributed refusal is a `throw`, so `tryEval` still classifies.
    test-attributed-refusal-still-catchable = {
      expr =
        (builtins.tryEval (attaches {
          aspect = "aspect:0";
          entity = x: x;
        })).success;
      expected = false;
    };
    # A derivation-shaped value with a broken `name` stays a CATCHABLE refusal (base behaviour).
    test-broken-name-derivation-still-catchable = {
      expr = (builtins.tryEval (hashIdentity "k" [ "a" ] (_: badDrv))).success;
      expected = false;
    };
  };
}
