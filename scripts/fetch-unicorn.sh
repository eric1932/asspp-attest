#!/bin/bash
# Fetches the interpreter-only Unicorn sources the iOS framework is built from:
# the TCI fork, plus qemu/target restored from its exact Unicorn 2.1.4 base
# (the fork's tree leaves it out). Prints the source directory to build.
#
# Also writes <dir>/unicorn-source.tar.gz: the exact sources, for anyone who
# receives the framework (GPL-2.0 section 3).
#
#   scripts/fetch-unicorn.sh <dir>
set -euo pipefail

dir="$1"
tci_repo=1rhino2/unicorn-tci
tci_commit=6d0794492de065cdf7e05d7658b4c1b157a34062
base_repo=unicorn-engine/unicorn
base_commit=8028ec436f2d9376525352dd38ed9ed6b9f6be10

fetch() {
    mkdir -p "$3"
    curl -fsSL --retry 3 "https://codeload.github.com/$1/tar.gz/$2" | tar -xz -C "$3" --strip-components 1
}

rm -rf "$dir"
mkdir -p "$dir"
fetch "$tci_repo" "$tci_commit" "$dir/unicorn-tci"
fetch "$base_repo" "$base_commit" "$dir/unicorn-base"
cp -R "$dir/unicorn-base/qemu/target" "$dir/unicorn-tci/unicorn-engine-sys-tci/qemu/"

cat > "$dir/unicorn-tci/SOURCE.txt" <<EOF
https://github.com/$tci_repo at $tci_commit
qemu/target from https://github.com/$base_repo at $base_commit
EOF
tar -czf "$dir/unicorn-source.tar.gz" -C "$dir" unicorn-tci

echo "$dir/unicorn-tci/unicorn-engine-sys-tci"
