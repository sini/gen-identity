# THE DOOR CONSTRUCTS — `checkOptions`, `checkRequired`, `resolve` (den-hoag-7gp66 P1).
#
# This plane pins what each construct ANSWERS and that every refusal is CATCHABLE (ADR-0025 item 1);
# ../tests-error.nix pins which refusal fired and that it names the door (R6).
#
# Each refusal cell sits beside an admission cell on the same fixture, so an implementation that
# refuses everything reds the admissions and one that admits everything reds the refusals.
{ genIdentity, ... }:
let
  inherit (genIdentity) checkOptions checkRequired resolve;
  refused = v: !(builtins.tryEval (builtins.deepSeq v v)).success;

  entries = {
    igloo = {
      name = "igloo";
      addr = "10.0.0.1";
      note = "n";
    };
    # A member whose `name` is not its identifier.
    yurt = {
      name = "renamed";
      addr = "10.0.0.2";
      note = "n";
    };
  };
  registry = {
    kind = "host";
    keys = [ "addr" ];
    inherit entries;
  };
  plain = resolve "gen-probe.door" registry;
  hinted = resolve "gen-probe.door" (registry // { hint = "name"; });

  # An entry whose identity key is computed THROUGH the resolver of its own registry. Minting every
  # entry to find `yurt` would force `cabin`'s key, which is being computed: the hinted resolver
  # mints only the candidates, so this evaluates.
  cyclic =
    let
      es = entries // {
        cabin = {
          name = "cabin";
          addr = es.${r entries.yurt}.addr + "-c";
        };
      };
      r = resolve "gen-probe.door" {
        kind = "host";
        keys = [ "addr" ];
        entries = es;
        hint = "name";
      };
    in
    es.cabin.addr;
in
{
  flake.tests.door-options = {
    test-accepted-options-pass-through-unchanged = {
      expr = checkOptions "gen-probe.door" [ "a" "b" ] { a = 1; };
      expected = {
        a = 1;
      };
    };
    test-empty-options-pass = {
      expr = checkOptions "gen-probe.door" [ "a" ] { };
      expected = { };
    };
    test-unknown-option-refused-catchably = {
      expr = refused (checkOptions "gen-probe.door" [ "a" ] { colr = 1; });
      expected = true;
    };
    test-non-set-options-refused-catchably = {
      expr = refused (checkOptions "gen-probe.door" [ "a" ] [ "a" ]);
      expected = true;
    };
  };

  flake.tests.door-record = {
    # R5's stated price: a data record is open, so an extra field is admitted and never reported.
    test-extra-field-on-a-record-is-admitted = {
      expr = checkRequired "gen-probe.door" [ "a" ] {
        a = 1;
        colr = 2;
      };
      expected = {
        a = 1;
        colr = 2;
      };
    };
    test-missing-required-field-refused-catchably = {
      expr = refused (checkRequired "gen-probe.door" [ "a" "b" ] { a = 1; });
      expected = true;
    };
    test-non-set-record-refused-catchably = {
      expr = refused (checkRequired "gen-probe.door" [ "a" ] null);
      expected = true;
    };
  };

  flake.tests.door-resolve = {
    test-identifier-resolves-to-itself = {
      expr = plain "igloo";
      expected = "igloo";
    };
    test-unknown-identifier-refused-catchably = {
      expr = refused (plain "nope");
      expected = true;
    };
    # den-hoag-3w9e7 arm (a): an identifier is a string, so an int is the wrong form.
    test-int-identifier-refused-catchably = {
      expr = refused (plain 1);
      expected = true;
    };
    test-lambda-refused-catchably = {
      expr = refused (plain (x: x));
      expected = true;
    };

    test-member-resolves-to-its-identifier = {
      expr = plain entries.igloo;
      expected = "igloo";
    };
    test-renamed-member-resolves-to-its-identifier = {
      expr = plain entries.yurt;
      expected = "yurt";
    };
    # A field outside the identity keys, a forged stamp included, does not move the identity: the
    # value resolves to the entry, and the door serves the entry rather than the value.
    test-non-key-edit-resolves-to-the-entry = {
      expr = plain (
        entries.igloo
        // {
          note = "x";
          id_hash = "host:forged";
        }
      );
      expected = "igloo";
    };
    test-key-edit-refused-catchably = {
      expr = refused (plain (entries.igloo // { addr = "evil"; }));
      expected = true;
    };
    test-non-member-refused-catchably = {
      expr = refused (plain {
        name = "igloo";
        addr = "10.9.9.9";
      });
      expected = true;
    };
    test-missing-key-refused-catchably = {
      expr = refused (plain {
        name = "ghost";
      });
      expected = true;
    };
    test-unmintable-key-refused-catchably = {
      expr = refused (plain {
        addr = x: x;
      });
      expected = true;
    };
    # The kind is the REGISTRY'S: a value carries no kind a caller cannot edit, so a value of
    # another kind whose key labels and values coincide with an entry's resolves to that entry.
    # Pinned so a change to that reading arrives as a red, not silently.
    test-kind-is-the-registrys = {
      expr = plain {
        addr = "10.0.0.1";
        kindOfSomethingElse = true;
      };
      expected = "igloo";
    };
  };

  flake.tests.door-resolve-hinted = {
    test-member-resolves = {
      expr = hinted entries.igloo;
      expected = "igloo";
    };
    test-renamed-member-resolves = {
      expr = hinted entries.yurt;
      expected = "yurt";
    };
    # The hint locates and never admits: a value naming a member but minting elsewhere is refused.
    test-hint-is-not-a-verdict = {
      expr = refused (hinted {
        name = "igloo";
        addr = "evil";
      });
      expected = true;
    };
    test-cyclic-registry-evaluates = {
      expr = cyclic;
      expected = "10.0.0.2-c";
    };
  };

  # Every refusal names the door first and the construct last (R6).
  flake.testsError.door-refusals =
    let
      pin = msg: {
        type = "ThrownError";
        msg = "^gen-probe[.]door: ${msg}$";
      };
    in
    {
      test-unknown-option-names-field-and-accepted-set = {
        expr = checkOptions "gen-probe.door" [ "a" "b" ] {
          a = 1;
          colr = 1;
        };
        expectedError = pin "'colr' is not an option of this door; the options are closed [(]accepted: 'a', 'b'[)] [(]in identity[.]checkOptions[)]";
      };
      test-non-set-options-named = {
        expr = checkOptions "gen-probe.door" [ "a" ] 3;
        expectedError = pin "the options must be an attrset, not a int [(]accepted: 'a'[)] [(]in identity[.]checkOptions[)]";
      };
      test-missing-field-named = {
        expr = checkRequired "gen-probe.door" [ "a" "b" ] { a = 1; };
        expectedError = pin "required field 'b' is missing [(]required: 'a', 'b'[)] [(]in identity[.]checkRequired[)]";
      };
      test-non-set-record-named = {
        expr = checkRequired "gen-probe.door" [ "a" ] null;
        expectedError = pin "the argument must be an attrset, not a null [(]required: 'a'[)] [(]in identity[.]checkRequired[)]";
      };
      test-unknown-identifier-named = {
        expr = plain "nope";
        expectedError = pin "reference 'nope' names no entry of the registry [(]in identity[.]resolve[)]";
      };
      test-wrong-form-named = {
        expr = plain 1;
        expectedError = pin "expected an identifier [(]a string[)] or a declaration [(]an attrset[)], got a int [(]in identity[.]resolve[)]";
      };
      test-missing-key-named = {
        expr = plain { name = "ghost"; };
        expectedError = pin "the declaration lacks identity key 'addr' [(]keys: 'addr'[)] [(]in identity[.]resolve[)]";
      };
      test-unmintable-key-named = {
        expr = plain { addr = x: x; };
        expectedError = pin "the declaration has no identity: a value under its keys [(]'addr'[)] does not mint [(]in identity[.]resolve[)]";
      };
      test-key-edit-named-non-member = {
        expr = plain (entries.igloo // { addr = "evil"; });
        expectedError = pin "the declaration is not a member of the registry [(]in identity[.]resolve[)]";
      };
      test-hinted-key-edit-named-non-member = {
        expr = hinted (entries.igloo // { addr = "evil"; });
        expectedError = pin "the declaration is not a member of the registry [(]in identity[.]resolve[)]";
      };
    };
}
