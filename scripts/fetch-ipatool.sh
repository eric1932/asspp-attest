#!/bin/bash
# Checks out ipatool at IPATOOL_COMMIT into <dir> and adds attestd as
# cmd/asspp-attestd. attestd imports ipatool's internal packages, so it can
# only be built inside an ipatool tree.
#
#   scripts/fetch-ipatool.sh <dir>
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$1"
commit="$(tr -d '[:space:]' < "$root/IPATOOL_COMMIT")"

rm -rf "$dir"
git init -q "$dir"
git -C "$dir" remote add origin https://github.com/majd/ipatool.git
git -C "$dir" fetch -q --depth 1 origin "$commit"
git -C "$dir" checkout -q FETCH_HEAD
mkdir -p "$dir/cmd/asspp-attestd"
cp "$root"/attestd/*.go "$dir/cmd/asspp-attestd/"
echo "$commit"
