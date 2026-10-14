FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl git ca-certificates zstd \
 && rm -rf /var/lib/apt/lists/*
RUN useradd -m lean
USER lean
WORKDIR /home/lean
ENV PATH="/home/lean/.elan/bin:${PATH}"
COPY --chown=lean:lean verification/lean/lean-toolchain verification/lean/lakefile.toml verification/lean/lake-manifest.json /home/lean/cache/
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh \
      | sh -s -- -y --default-toolchain "$(cat /home/lean/cache/lean-toolchain)" \
 && cd /home/lean/cache && printf 'import Mathlib\n' > Diana.lean && mkdir -p Diana \
 && lake exe cache get && rm -f Diana.lean
