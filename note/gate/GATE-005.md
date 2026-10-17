---
id: GATE-005
title: Allowed axioms in script/axiom_allow.yaml
kind: fact
path:
  - script/axiom_allow.yaml
related: [GATE-004, FP-001]
---
`script/axiom_allow.yaml` is the complete list of axioms a listed constant may depend on; any other
axiom gives the constant the status `axiom: <name>` (GATE-004).

- `lean`: `propext`, `Classical.choice`, `Quot.sound`.
- `rocq`:
  - `ClassicalDedekindReals.sig_forall_dec` and `ClassicalDedekindReals.sig_not_dec`, the
    classical reals of the Rocq standard library;
  - `FunctionalExtensionality.functional_extensionality_dep`;
  - `Classical_Prop.classic`, excluded middle;
  - `Axioms.prop_ext` and `Ensembles.Extensionality_Ensembles`, from VST's foundations, which
    the VST body lemmas depend on.

There is no other entry; in particular no axiom describes an external call, since no verified
kernel calls a function outside Diana (FP-001). A new entry enlarges the trust base and must be
stated in the trust statement.
