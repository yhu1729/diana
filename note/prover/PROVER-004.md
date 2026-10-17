---
id: PROVER-004
title: Why3 1.8.2 configures Alt-Ergo 2.6.x but not Homebrew Z3 5.x
kind: fact
path:
  - script/run_frama_c.sh
related: [PROVER-002, WP-007]
---
WP reaches its prover through Why3, and `why3 config detect` only configures a prover version
listed in Why3's detection data (`share/why3/provers-detection-data.conf` in the opam switch).
Why3 1.8.2 accepts Alt-Ergo `2.6.x` (driver `alt_ergo_26`) and Z3 only up to `4.13.x`, so the
Homebrew Z3 5.x on the development Mac is found but gets no configuration.

The project therefore uses Alt-Ergo alone: `script/run_frama_c.sh` passes `-wp-prover alt-ergo`,
and in the WP report the only prover besides WP's own `Qed` simplifier is `Alt-Ergo 2.6.4`.
Rerun `why3 config detect` after installing or upgrading a prover.
