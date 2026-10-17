---
id: PROOF-006
title: RK4 layer A, local error O(h⁵) and global error O(h⁴)
kind: fact
path:
  - spec/rk4.md
related: [PROOF-008, PROOF-005, PROOF-007]
---
Lean and Rocq prove that classical RK4 with exact slopes has local error `O(h⁵)` and global error
`O(h⁴)` (`spec/rk4.md`, RK4-A1 to A7), in the max norm.

- H1: `y′ = F(t, y)` is treated as `z′ = G(z)`, `z = (t, y)`, `G(t, y) = (1, F(t, y))`, with
  derivatives `G′`, `G″`, `G‴` (Lean: Fréchet; Rocq: along curves plus linearity in each
  argument); no fourth derivative of `G`.
- H2: `Y′ = G(Y)` on `[t, t + h]` and `‖E₄(Y(s)) − E₄(Y(t))‖ ≤ M₅·(s − t)`, `E₄` the fourth
  derivative of `Y` written through `G′`, `G″`, `G‴`; it holds when `‖Y⁽⁵⁾‖ ≤ M₅`.
- H3: the increment `Φ(s)` of a step of size `s` has `‖Φ‴(s) − Φ‴(0)‖ ≤ N₄·s` on `[0, h]`; it
  holds when `‖Φ⁗‖ ≤ N₄`, and is a hypothesis on the method applied to `F`, not on `F` alone.
- H4: `F` is `L`-Lipschitz in `y`, `L > 0`.
- A1: explicit jets are the first three step-size derivatives of `Φ`. A2: order conditions
  `Φ(0) = G(y)`, `Φ′(0) = E₂(y)/2`, `Φ″(0) = E₃(y)/3`, `Φ‴(0) = E₄(y)/4`, using linearity only
  (no symmetry of `G″`).
- A3 (H1 to H3, `h ≥ 0`): `‖Y(t + h) − Y(t) − h·Φ(h)‖ ≤ (M₅/120 + N₄/24)·h⁵` (Rocq also takes
  `0 ≤ M₅`, `0 ≤ N₄`).
- A4: if `F(s, ·)` is `L`-Lipschitz on `[t, t + h]`, `h ≥ 0`, `L ≥ 0`, then
  `‖Φ(t, y) − Φ(t, z)‖ ≤ L·(1 + hL/2 + (hL)²/6 + (hL)³/24)·‖y − z‖`.
- A5 (H4 on `[t₀, t₀ + N·h]`, `h > 0`): a one-step error of at most `τ ≥ 0` from the solution
  at every grid point gives `‖y_k − Y(t₀ + k·h)‖ ≤ τ/(hL)·(e^{L·k·h} − 1)`, `k ≤ N`.
- A6: the increment of `(1, F)` is `(1, Φ)`, so RK4 on the augmented state is RK4 on `y` with
  stage times `t + h/2` and `t + h`.
- A7 (H1, H4, `Y′ = F(t, Y)` on `[t₀, t₀ + N·h]`, H2 and H3 at every grid point for `G = (1, F)`
  and `Ŷ(s) = (s, Y(s))`, `h > 0`):
  `‖y_k − Y(t₀ + k·h)‖ ≤ ((M₅/120 + N₄/24)·h⁴/L)·(e^{L·k·h} − 1)` for `k ≤ N`.

Rounding and the C code are PROOF-008.
