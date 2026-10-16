FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl git ca-certificates zstd python3 python3-yaml \
 && rm -rf /var/lib/apt/lists/*
ENV PATH="/root/.elan/bin:${PATH}"
ENV DIANA_LEAN_CACHE=/opt/diana-lean
WORKDIR /opt/diana-lean
COPY verification/lean/lean-toolchain verification/lean/lakefile.toml verification/lean/lake-manifest.json ./
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
      | sh -s -- -y --default-toolchain "$(cat lean-toolchain)" \
 && printf 'import Mathlib\n' > Diana.lean && mkdir -p Diana \
 && lake exe cache get && rm -f Diana.lean
