#!/bin/sh
# Install the Alt-Ergo of the toolchain pin, the static Linux x86-64 release binary checked
# against its SHA-256, as DIR/alt-ergo (default .cache/alt-ergo). CI puts DIR first on PATH,
# since the framac/frama-c image ships another Alt-Ergo. Usage: fetch_alt_ergo.sh [DIR]
set -eu
version=2.6.4
sha256=80d41dd9cf4b024be7412e499f81960ddc63978f5d78a29311a05aaab125681a
url=https://github.com/OCamlPro/alt-ergo/releases/download/v$version/alt-ergo-v$version-x86_64-linux-musl
dir=${1:-.cache/alt-ergo}

if [ "$(uname -s)-$(uname -m)" != Linux-x86_64 ]; then
    echo "error: the pinned binary is for Linux x86-64; elsewhere install alt-ergo.$version with opam" >&2
    exit 1
fi

digest() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
    fi
}

mkdir -p "$dir"
if [ ! -x "$dir/alt-ergo" ] || [ "$(digest "$dir/alt-ergo")" != "$sha256" ]; then
    tmp="$dir/alt-ergo.part"
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL -o "$tmp" "$url"
    else
        wget -q -O "$tmp" "$url"
    fi
    got=$(digest "$tmp")
    if [ "$got" != "$sha256" ]; then
        rm -f "$tmp"
        echo "error: $url has SHA-256 $got, expected $sha256" >&2
        exit 1
    fi
    chmod 755 "$tmp"
    mv "$tmp" "$dir/alt-ergo"
fi
"$dir/alt-ergo" --version
