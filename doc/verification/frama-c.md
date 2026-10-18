# Frama-C

Each verified C function carries an ACSL contract in a `/*@ ... */` comment, and Frama-C's WP
plugin proves it with Alt-Ergo, using a floating-point model and the runtime-error plugin. That
covers memory safety, the absence of undefined behaviour, and the contract itself: which statuses
occur, that outputs are untouched on error, and the invariant of a state machine.

## Run it

`script/verify_frama_c.sh` proves every source file listed in `verification/frama-c/expectation.txt`
and checks the result; CI runs the same script in `verify_frama_c`. Each row of that file pairs a
source with its number of proof goals. The check fails when a goal is not proved, and also when
the count changes: a drop means a contract or a runtime check disappeared. After changing a
contract, update the count in the same commit. The output is collected in
`verification/frama-c/report.txt`.

## Writing a contract

- In ACSL, arithmetic on `double` is exact real arithmetic; write a rounded value with a cast,
  `(double)(a + b)`. Never write a hexadecimal float literal: WP rejects or mistranslates it.
- Predicates shared by a kernel's functions go in its private header, such as
  `src/bisection_acsl.h`.
- A floating-point fact beyond WP's reach goes into a small helper function of its own whose
  contract WP assumes, and Flocq and VST prove instead: the bisection midpoint and the square
  root of the Cholesky factorization; the script fails if WP would assume any other contract, and
  also if it cannot read Frama-C's list of the called functions, as after a format change.
- A nonlinear index bound such as `i + j*n < n*n` needs a lemma in the factored form Alt-Ergo can
  prove and an assertion that instantiates it in each loop.

## Technical notes

[WP-001](../../note/wp/WP-001.md) ACSL arithmetic,
[WP-002](../../note/wp/WP-002.md) no hexadecimal literal,
[WP-003](../../note/wp/WP-003.md) the `SKIP` trust boundary,
[WP-011](../../note/wp/WP-011.md) nonlinear index bounds,
[WP-004](../../note/wp/WP-004.md) how it is enforced,
[WP-007](../../note/wp/WP-007.md) goal counts,
[WP-008](../../note/wp/WP-008.md) parallel rows,
[WP-009](../../note/wp/WP-009.md) sessions and caches,
[WP-010](../../note/wp/WP-010.md) recovering from a cache failure.
