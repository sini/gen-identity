# gen-identity — THE SUBSTRATE'S ONE IDENTITY MINT.
#
# `hashIdentity` is the one minting authority; nothing else mints (ADR-0016 ruling 5). An
# identity is a kind tag joined to a digest of the ⟨label, value⟩ pairs:
#
#     identity = "<kind>:" + sha256(<pairs preimage>)
#
# and the preimage is produced by a BOUNDED, TYPE-TAGGED canonical encoding of inert Nix
# values. What cannot be encoded totally gets no identity at all and is refused by name — a
# lambda, a path, a derivation, a value that diverges under its own bounds. String CONTEXT is
# not identity-bearing, at any position the mint takes a string: a context-carrying string — a
# derivation's string form included — is admitted as its text, mints the identity of its `==`
# context-free twin, and no minted identity carries context (ADR-0016 ruling 4, inherited by
# ADR-0034 over the whole admitted domain; `ci/tests/string-context.nix`).
#
# ★ A LAZY SOURCE PATH MINTS A PER-EVALUATION IDENTITY. Under lazy trees (Determinate Nix,
# `lazy-trees = true`) a flake input's `outPath` renders as a virtual store path that is fresh in
# every evaluation, and `==` compares that virtual text; so its identity, which follows `==`, is
# consistent within one evaluation and differs across them. ADR-0016 ruling 5 makes that lawful:
# the identity is internal addressing, and nothing durable may depend on it across evaluations.
# ⇒ An identity minted over a lazy source path MUST NOT reach a derivation, a file, or any other
# carrier that outlives the evaluation: measured, a derivation holding one gets a new drvPath in
# every evaluation, so it is never cached, while upstream Nix shows the same identity every time.
# ADR-0034's friction rider does not fire: the mint pays the design's price — ruling 4 holds in
# both directions, ruling 5 admits the per-evaluation identity, no regime or excluded population
# changes — and the change sits in this one authority, stated here rather than absorbed at a site.
#
# ★ THIS LIBRARY IS DEPENDENCY-FREE, AND THAT IS A MEASUREMENT RATHER THAN AN INTENTION. The
# content below is `builtins` and nothing else: it evaluates with every substrate argument
# poisoned, and `ci/tests/purity.nix` scans it for every substrate identifier — not merely for
# a nixpkgs tether — because *dependency-free* is a stronger claim than *nixpkgs-lib-free* and
# a scan checking only the weaker one would go green on a library that had grown a parameter.
#
# ★ WHY IT IS ITS OWN LIBRARY, since the content lived in gen-schema until it moved here. The
# mint sat DOWNSTREAM of libraries that need it — gen-types cannot reach gen-schema without
# closing a flake dependency cycle — so its consumers either injected it through a parameter
# or went without. A leaf with no substrate to depend on can be reached by everything, which
# is what a single minting authority has to be. Relocating the code does not relocate the
# assignment: ADR-0016 ruling 5 gives the concern to the SUBSTRATE, and that is the stratum
# this library declares.
#
# ★ WHAT IS NOT HERE, so a reader looks in the right place. The REFLECTION half stays in
# gen-schema: deciding which of a kind's declared options are identity keys
# (`isPrimitiveOption`), recomputing an instance's hash from a kind value
# (`identityHashForKind`), and stamping `id_hash` onto an instance (`mkIdentityModule`). All
# of it reads option metadata and builds options with the module system, which is a
# module-system concern in every part. It calls into this library; it does not belong to it.
#
# Zero dependencies, so this is a bare value (not a function): `import ./lib`.
let
  # 2^53 — the magnitude past which Nix's `==` stops being an equivalence relation across int and
  # float. `9007199254740993 == 9007199254740992.0` and `9007199254740992 == 9007199254740992.0`
  # are both true while `9007199254740993 == 9007199254740992` is false: two ints that are not
  # equal to each other are both equal to one float, because int/float comparison converts through
  # a double and 2^53+1 is not representable in one.
  #
  # The bound is STRICT — 2^53 itself is EXCLUDED — and the reason is that colliding float: it sits
  # AT the bound, not above it. An inclusive bound would admit `9007199254740992.0` as a float,
  # admit `9007199254740993` as an unrestricted int, and then send two `==`-equal admitted values to
  # different digests, i.e. break the identity law INSIDE its own declared domain. Excluding the
  # endpoint removes the float side of the only such pair, which is what leaves ints unrestricted:
  # for |f| < 2^53 an integral f normalises to an exact int, and an int of magnitude above 2^53
  # converts to a double no smaller than 2^53, which no admitted f can equal.
  exactBound = 9007199254740992.0;

  # Every value must be admitted by a PREDICATE before it reaches a builtin, because a builtin's
  # own failure is not a refusal. `builtins.toJSON` on a function, `builtins.floor` outside NixInt
  # range and float division by zero each escape `tryEval` and abort the whole evaluation, so they
  # cannot be caught, attributed to a kind and label, or asserted on in a test — an unnamed abort
  # inside the identity mechanism is a silent failure wearing a loud error. Each branch below either
  # emits a tagged rendering or throws by name.
  #
  # Identity follows the LANGUAGE'S `==`, in both directions — neither coarser nor finer. Nothing
  # renders through `toString`, which is coarser than `==`: it collapses distinct doubles at six
  # decimal places.
  #
  # ★ STRUCTURE IS EMITTED, NEVER DELEGATED, and that is forced rather than preferred.
  # `builtins.toJSON` is NOT structure-preserving on attrsets: a record carrying `outPath` renders
  # as that string ALONE, discarding every sibling attribute, so `{ outPath = "x"; a = 1; }` and
  # `{ outPath = "x"; a = 2; }` both render `"x"` and both equal the rendering of the bare string
  # `"x"` — while Nix `==` distinguishes all three. A composite preimage therefore cannot be
  # `toJSON` of the value. The encoder emits the structure itself and applies `toJSON` only to
  # STRINGS — values and attribute keys — the one position where that coercion cannot arise and
  # where JSON's self-delimiting quoting and escaping is exactly what is wanted.
  #
  # ★ THE TYPE TAG ON EVERY NODE IS WHAT MAKES FORGERY INEXPRESSIBLE rather than blocked case by
  # case: a string can never render as a list or a record because its rendering begins `s`, and a
  # key can never render as a value because it is JSON-quoted and colon-terminated. The scalar
  # semantics are inherited unchanged — the strict |v| < 2^53 float domain, integral-float
  # normalisation to an int, `==` as the reference relation. `null` joins them, tagged `z`: the
  # string "null" tags `s"null"` and an omitted key emits no pair at all, so neither collides.
  #
  # `builtins.attrNames` returns keys sorted, so order-freedom-by-construction recurses to every
  # depth and no caller owes a sort; Nix `==` on lists respects order, so lists encode in order and
  # owe none either.

  # ── the bounds, and the THREE axes they answer ──
  #
  # TWO DECLARED BOUNDS — PREIMAGE LENGTH and WALK DEPTH — each on the quantity it actually
  # measures, and NEITHER IMPLIES THE OTHER: a shared DAG has small depth and an exponential
  # preimage, while a deep thin chain has a small preimage and unbounded depth.
  #
  # ★★ BREADTH IS THE THIRD AXIS, AND IT IS NOT ANSWERED BY A THIRD BOUND. A wide value sits inside
  # both declared bounds — a 31,000-element list is 62,009 preimage characters and two levels deep —
  # yet it escaped them both, because the fold accumulated the budget and the string as THUNK CHAINS
  # that nothing forced until the walk was over. The bounds were not too loose; they had not been
  # EVALUATED. Breadth is answered in the composite fold, by forcing its accumulator and each member
  # at every step, and the length budget then does the bounding: it caps member count as a consequence, since every
  # member emits at least its separator. Measured at this budget: 32,763 null members mint, 32,764
  # refuse BY NAME.
  #
  # WHY BOUNDS RATHER THAN CYCLE DETECTION: deciding "reachable from itself" needs an observation
  # of sharing, and Nix's builtin surface offers none — structural `==` on a cyclic value diverges
  # for the same reason this walk would. A bound converts an UNDETECTABLE divergence into a
  # NAMEABLE refusal, which is the only form the mint admits.
  #
  # ★ The depth bound is not a free parameter: it owes `depth × calls-per-node < max-call-depth`,
  # and both factors are evaluator and implementation facts rather than encoding facts. MEASURED on
  # this encoder, with the depth bound lifted and the budget as shipped: a thin RECORD chain mints a
  # little under two thousand levels deep and, just above that, aborts UNCATCHABLY with
  # `stack overflow; max-call-depth exceeded` — Nix's own call-depth guard, configured at 10,000,
  # and not a raw C-stack limit. That puts this encoder at ROUGHLY FIVE Nix call frames per record
  # level (a list level is one fewer), so the constraint reads 512 × 5 < 10,000 and the bound of 512
  # carries a measured margin of about 4×.
  #
  # ★ THE CROSSOVER IS AN INTERVAL AND MUST NOT BE WRITTEN AS A LEVEL. `max-call-depth` counts a
  # GLOBAL frame budget, not this walk's depth, so whatever else the surrounding evaluation is
  # holding open moves the exact level. The two figures worth carrying are the STABLE ones — about
  # five frames per level, and about a 4× margin behind the shipped bound — because those survive
  # the harness moving underneath them.
  #
  # ★ THAT MARGIN IS SMALLER THAN THE THREADED ENCODER'S, AND THE CAUSE IS RECORDED so the two are
  # not reasoned about separately. The threaded encoder spent about three frames per level (a margin
  # of about 6×), because each fold step returned a record and its string was concatenated without a
  # call; the checked encoder forces each member inside the fold step that charges it, so the fold
  # and its step hold frames across the descent. That is the price of building the preimage without
  # a record per fragment. The composite branch is written to spend the fewest frames that ordering
  # allows (see its comment); an implementation with a heavier per-node call count owes its own
  # margin measurement rather than inheriting this one.
  #
  # ★ THE PRICE IS REAL AND IS NOT HIDDEN: a value with FEW DISTINCT NODES is refused when its
  # EXPANSION exceeds the budget, because what a walk pays is the expansion and not the node count.
  # Every derivation — every package — is excluded outright, and so is every self-referential
  # value. An ordinary identity record encodes to a few dozen characters, so the budget carries
  # about three orders of magnitude of headroom over the population that actually mints.
  identityBudget = 65536;
  identityDepth = 512;

  # The encoder is INSTANTIATED PER LABEL, closing over that label's refusal FRAME (the kind and
  # the label), so every refusal raised inside a label's walk, the composite fold's budget refusal
  # included, names both without an argument threaded through the walk. A threaded argument is one
  # more application per value node on the success path; a closure is paid once per label and
  # never per node. The frame is only ever read inside a `throw`, so building it costs nothing
  # until a refusal fires. It is built from the kind and the label alone, both strings that have
  # already passed their guards: a refusal never reads caller data to describe it, because a read
  # that fails in a way `tryEval` does not contain would turn a named refusal into an abort.
  # What a refusal names: the kind and, inside a label's walk, the label. Both are strings that have
  # passed their guards, and `toJSON` is total on a string. Only ever called inside a `throw`.
  frameOf =
    kind: label:
    "; kind ${builtins.toJSON (builtins.unsafeDiscardStringContext kind)}"
    + (if label == null then "" else ", label ${builtins.toJSON label}");
  # Called only inside the duplicate-key `throw`, after every label has passed the string guard.
  dupOf =
    labels:
    let
      names = map builtins.unsafeDiscardStringContext labels;
    in
    builtins.head (builtins.filter (l: builtins.length (builtins.filter (x: x == l) names) > 1) names);

  mkEncoder =
    kind: label:
    let
      over = throw "identity: preimage exceeds the identity budget${frameOf kind label}";

      # enc : depth -> budget -> value -> string
      enc =
        d: r: v:
        if d > identityDepth then
          throw "identity: value nests deeper than the identity depth bound${frameOf kind label}"
        # A string's CONTEXT is not identity-bearing: `==` ignores it, and ruling 4 makes `==` the
        # reference relation. The context is discarded HERE, at the leaf, as the kind and the labels
        # discard it where they enter, so no preimage piece ever carries context. It is owed: under lazy
        # trees `==` compares a lazy source path's virtual text, while `hashString` on a context-carrying
        # argument devirtualises it to the real store path, copying the tree into the store. Without the
        # discard, a string and its `==` twin would mint apart. The identity of a lazy source path is
        # therefore per-evaluation, which ADR-0016 ruling 5 licenses (see the header). The derivation
        # exclusion below is a TYPE test on the value, for termination; a derivation's string form is a
        # leaf and, discarded here, reaches no store effect inside the mint, so it mints as its text. That
        # holds only here: a consumer keying an attrset by the INPUT string, not by the identity, still
        # meets Nix's attribute-name refusal.
        else if builtins.isString v then
          "s" + builtins.toJSON (builtins.unsafeDiscardStringContext v)
        else if builtins.isBool v then
          (if v then "b1" else "b0")
        else if builtins.isInt v then
          "i" + builtins.toString v
        else if builtins.isFloat v then
          (
            if !(v > (0.0 - exactBound) && v < exactBound) then
              throw "identity: float outside the exactly-representable integer range${frameOf kind label}"
            else if v == builtins.floor v then
              "i" + builtins.toString (builtins.floor v)
            else
              "f" + builtins.toJSON v
          )
        else if v == null then
          "z"
        # A composite renders as an opening tag, each member followed by the separator, and a closing
        # tag. A node RETURNS ITS STRING: the budget is CHECKED against the strings, not threaded
        # through them. `r` is the budget remaining before the opening tag, and every member is encoded
        # against `r - 1`, the budget left after that tag — an UPPER bound on what the member may
        # spend, so a member too long on its own refuses inside its own walk. The fold then charges the
        # members' ACTUAL lengths, separator included, in order, and refuses at the first member that
        # leaves no room for the closing tag, before a later member is forced.
        #
        # ★★ THE FOLD IS WHAT BOUNDS BREADTH — the third axis, which neither the length budget nor the
        # depth bound reaches on its own. Its accumulator is a flat int, so `foldl'`'s WHNF force is
        # full evaluation, and each member's string is forced as the fold reaches it: no budget and no
        # concatenation is left to accrete as a thunk chain the walk never inspects, and the join is
        # one `concatStringsSep` over strings already forced. An unforced n-link chain is what a wide
        # value overflows on, uncatchably: a 31,000-element list — preimage 62,009 characters, depth 2,
        # inside both bounds — aborts with `stack overflow` when either is left to accrete. This is
        # ADR-0022's probe constraint arriving in the identity domain: every round-loop accumulator is
        # forced per round.
        #
        # ★ THE DESCENT SPENDS AS FEW CALL FRAMES AS IT CAN, because the depth bound's margin is
        # frames per level (see the bounds above). An arithmetic or comparison operator is a builtin
        # call and holds a frame while it forces its operand, so the member and the fold's result are
        # forced by native `!=` / `==` instead, and a list member is a partial application of `enc`
        # rather than a wrapping lambda: a list level costs `enc`, `foldl'` and the fold's step, and a
        # record level one more, its key-prefixing lambda.
        #
        # ★ WHY CHECKED AND NOT THREADED. Threading the exact remaining budget through every node costs
        # a `{ s; b; }` record and a continuation per fragment, which is most of what a mint spends
        # when the budget is threaded. The preimage is byte-identical either way,
        # so no identity moves, and a value is refused for length exactly when its preimage exceeds the
        # budget, since the outer frame charges the exact remainder. What the upper bound changes is
        # confined to values that are REFUSED either way, and it is stated rather than left to be found:
        #   - WHICH refusal names a value: one over budget that ALSO holds a lambda, path, derivation or
        #     depth refusal inside the member that crosses can name that refusal rather than the budget,
        #     because the member is walked against its upper bound before the fold charges it;
        #   - WHAT a refusal costs: up to about one budget of walked members per enclosing level, so
        #     `identityDepth × identityBudget` characters at worst rather than one budget — bounded,
        #     and never the expansion the refusal declined to build.
        else if builtins.isList v || builtins.isAttrs v then
          let
            list = builtins.isList v;
            d' = d + 1;
            r' = r - 1;
            strs =
              if list then
                map (enc d' r') v
              # A DERIVATION IS REFUSED BY TYPE TEST, BEFORE ANY DESCENT. A derivation's output attribute is
              # self-referential (`drv.out.out.out.name` resolves), so an unbounded walk over one does not
              # terminate. This gate exists for TERMINATION and not for forgery — the tagged encoding
              # already closes the `outPath` channel.
              #
              # ★★ THE TEST IS THE FULL THREE-ATTRIBUTE SHAPE, AND THE NARROWER FORM WAS DISCONTINUOUS UNDER
              # NESTING. Testing `type` alone refuses any record whose `type` field happens to hold the
              # string "derivation" — an ordinary declaration, since a `str` option may be named anything.
              # That made ADMISSIBILITY DEPEND ON POSITION rather than on the value: measured, the record
              # `{ type = "derivation"; n = 1; }` MINTED as the mint's own outer frame and REFUSED one level
              # down, with the same shape carrying `type = "ordinary"` minting at both. Position-dependent
              # admissibility is what ADR-0034's "inert composites are admitted" cannot survive, so the
              # population it applies to had to shrink.
              #
              # ★ IT SHRANK; IT DID NOT VANISH, and the residue is stated rather than left to be found. The
              # mint's outer FRAME never reaches this gate at all — it is synthesized by the mint and is not
              # caller data — so a record of the full three-attribute shape STILL mints at the frame while
              # refusing everywhere caller data can put it. `test-derivation-shape-refused-wherever-caller-
              # data-reaches` pins exactly that, frame arm included. What changed is which values sit in the
              # discontinuous population: it was every record whose `type` field held a string, which is an
              # ordinary declaration, and it is now only the full derivation shape, which no kind declares
              # by accident. The remaining discontinuity errs toward MINTING a synthesized frame rather than
              # refusing a legitimate value, which is the direction that costs an identity nothing.
              #
              # Requiring `drvPath` and `outPath` alongside `type` costs no termination guarantee: what does
              # not terminate is the self-referential output attribute, and a record carrying all three
              # WITHOUT that structure is finite and bounded like any other. The three-attribute shape is
              # what an actual derivation has, so every value the gate exists to stop is still stopped.
              # Presence tests do not force, so widening the gate forces nothing new either.
              else if (v.type or null) == "derivation" && v ? drvPath && v ? outPath then
                throw "identity: a derivation in an identity position${frameOf kind label}"
              else
                map (k: builtins.toJSON k + ":" + enc d' r' v.${k}) (builtins.attrNames v);
            left = builtins.foldl' (
              a: str:
              # Never fires: every rendering begins with its type tag. It forces the member natively.
              assert str != "";
              let
                a' = a - builtins.stringLength str - 1;
              in
              if a' < 1 then over else a'
            ) (r - 1) strs;
          in
          # A member leaves room for the closing tag, so only an EMPTY composite reaches `0` here.
          if left == 0 then
            over
          else
            (if list then "[" else "{")
            + builtins.concatStringsSep "," strs
            + (if strs == [ ] then "" else ",")
            + (if list then "]" else "}")
        else
          # Lambdas and paths land here, named by their own type. A lambda has no eliminator in Nix — no
          # builtin exposes a closure's captured environment or its body — so no preimage over one can
          # be TOTAL, and an identity minted over a partial preimage merges behaviourally distinct
          # values. A path is refused because `toJSON` on a file path silently copies it to the store
          # and on a directory path aborts uncatchably.
          throw "identity: a ${builtins.typeOf v} in an identity position${frameOf kind label}";
    in
    {
      # One field of the mint's own frame: the JSON-rendered key, a colon, then the field's encoding
      # from depth 1, charged against `b`, the frame's EXACT remaining budget. The frame threads it
      # (see `canonicalPreimage`), so a budget refusal at the frame names the label that crossed.
      field =
        b: v: k:
        let
          key = builtins.toJSON k + ":";
          str = key + enc 1 (b - builtins.stringLength key) v.${k};
          rest = b - builtins.stringLength str;
        in
        if rest < 0 then
          over
        else
          {
            s = str;
            b = rest;
          };
    };

  # The PAIRS preimage — a digest of the ⟨label, value⟩ pairs alone. The kind is NOT in it; it rides
  # outside, on the join in `hashIdentity`.
  #
  # Order-insensitivity is BY CONSTRUCTION rather than by a sort the caller owes: the pairs are
  # rendered as a Nix ATTRSET and `attrNames` yields its keys sorted. A caller supplying
  # `[ "user" "host" ]` and one supplying `[ "host" "user" ]` therefore mint the same node with no
  # sorting anywhere and no contract for a caller to get wrong.
  #
  # `listToAttrs` is what buys that, and it is also what forces the duplicate-label refusal: without
  # it a repeated label would SILENTLY collapse, which trades one order defect for one arity defect.
  # The structural refusals are checked on the LABEL LIST, before any value is forced, so the first
  # error a caller sees names the structural mistake and not a downstream symptom of it.
  #
  # ★ THE OUTER FRAME IS THE MINT'S OWN, so it is rendered by its own fold DIRECTLY rather than
  # by handing a synthesized record back to `enc`. Routing it through the walk would
  # apply the derivation gate to a record the mint just built, and a kind carrying an ordinary
  # `type` option whose value happened to be the string "derivation" would then be refused an
  # identity it is entitled to. The frame is not caller data; its FIELDS are, and those take the
  # full walk from depth 1.
  canonicalPreimage =
    kind: labels: valueOf:
    let
      pairs = builtins.listToAttrs (
        # A label's context is discarded (ruling 4): `listToAttrs` aborts uncatchably on a context-
        # carrying name, and two labels differing only in context are `==`-duplicates, refused
        # below by name. The non-string guard is forced first, so the discard never coerces a set
        # or a path. Live for DIRECT callers only: labels built from `attrNames` carry no context.
        # `valueOf` receives the DISCARDED label too: a caller indexing by it (`l: relata.${l}`)
        # would otherwise abort, and a `valueOf` observing context would split `==` label lists.
        map (
          l:
          let
            name = builtins.unsafeDiscardStringContext l;
          in
          {
            inherit name;
            value = valueOf name;
          }
        ) labels
      );
    in
    if labels == [ ] then
      throw "identity: zero identity keys${frameOf kind null}"
    # Before `listToAttrs` is forced: its own type failure on a non-string name escapes `tryEval`.
    else if !builtins.all builtins.isString labels then
      throw "identity: a ${
        builtins.typeOf (builtins.head (builtins.filter (l: !builtins.isString l) labels))
      } as an identity-key label; a label is a string${frameOf kind null}"
    else if builtins.length labels != builtins.length (builtins.attrNames pairs) then
      throw "identity: duplicate identity key ${builtins.toJSON (dupOf labels)}${frameOf kind null}"
    else
      # The mint's own frame names the kind; each label's walk runs in that label's own instance.
      let
        over = throw "identity: preimage exceeds the identity budget${frameOf kind null}";
        # Both fields forced per label, for the reason the composite fold forces its own.
        stepped =
          builtins.foldl'
            (
              acc: k:
              let
                f = (mkEncoder kind k).field acc.b pairs k;
                s = acc.s + f.s + ",";
                b = f.b - 1;
              in
              if b < 0 then over else builtins.seq s { inherit s b; }
            )
            {
              s = "{";
              b = identityBudget - 1;
            }
            (builtins.attrNames pairs);
      in
      if stepped.b < 1 then over else stepped.s + "}";

  # The SINGLE minting authority. An identity is the kind tag joined to a digest of the pairs:
  #
  #     identity = "<kind>:" + sha256(<pairs preimage>)
  #
  # The tag rides OUTSIDE the digest. What identity has to deliver here is DISTINCTNESS, not
  # cryptographic integrity, and since nothing but this function mints there is no second writer for
  # a hashed-in prefix to authenticate against. What riding outside buys is that an identity says
  # what it is: the kind is recoverable by splitting on the first colon, with no reverse lookup, and
  # a trace reads. The digest region is consequently kind-INDEPENDENT — two relations over identical
  # relata share it — so the identity is the WHOLE STRING and a consumer that slices the digest out
  # of it is not comparing identities.
  #
  # That join is the one place a value could reach the structure, and it is closed on the kind side
  # by refusing `:` in a kind name. Inside the pairs preimage the same class is closed by a
  # different mechanism — JSON is self-delimiting, quoting string values and escaping internal
  # quotes and backslashes — which is why a VALUE may contain a colon and a KIND may not. Relatum
  # identities are themselves colon-bearing, so that asymmetry is load-bearing rather than
  # incidental: data is escaped, structure is constrained.
  hashIdentity =
    kind: labels: valueOf:
    # First, so only a string reaches `match` and the join: a builtin's type failure escapes `tryEval`.
    if !builtins.isString kind then
      throw "identity: a ${builtins.typeOf kind} as the relation kind; a kind is a string"
    else if kind == "" then
      throw "identity: empty relation kind"
    else if builtins.match "[^:]*" kind == null then
      throw "identity: ':' is the kind separator and is refused in a kind name"
    # The kind's context is discarded (ruling 4): riding outside the digest, it would otherwise carry
    # a store dependency into the identity, which then aborts as an attribute name. Only a string
    # reaches here — the guards above must stay first, or the discard would coerce a set.
    else
      "${builtins.unsafeDiscardStringContext kind}:"
      + builtins.hashString "sha256" (canonicalPreimage kind labels valueOf);
in
{
  inherit hashIdentity;
}
