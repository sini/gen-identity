# gen-identity has no dependencies of any kind — not nixpkgs, not a gen substrate. Zero
# dependencies do not make the standalone (non-flake) entry a bare value: it is a NULLARY
# FUNCTION, so `import ./. { }` is the one call text that answers every roster member
# alike, leaf or not, and gen-identity gaining a dependency later changes what the empty
# pattern defaults to, never the call text at this root (den-hoag-iev2q). The empty
# pattern, not `_:` — `_:` would silently accept and drop an unexpected argument; `{ }:`
# refuses one loudly.
{ }: import ./lib
