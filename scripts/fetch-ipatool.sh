#!/bin/bash
# Checks out ipatool at IPATOOL_COMMIT into <dir> and adds attestd as
# cmd/asspp-attestd. attestd imports ipatool's internal packages, so it can
# only be built inside an ipatool tree.
#
# One patch, which only builds with -tags asspp_embedded see: on macOS the
# framework links Unicorn statically, so ipatool must find it in the process
# (as its iOS build does) instead of downloading libunicorn.
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

unicorn="$dir/internal/sap/unicorn"
unix_tag='//go:build (darwin && !ios) || linux'
if [ "$(head -1 "$unicorn/library_unix.go")" != "$unix_tag" ]; then
    echo "ipatool's Unicorn loader changed; update the patch in $0" >&2
    exit 1
fi
{
    echo '//go:build (darwin && !ios && !asspp_embedded) || linux'
    tail -n +2 "$unicorn/library_unix.go"
} > "$unicorn/library_unix.go.new"
mv "$unicorn/library_unix.go.new" "$unicorn/library_unix.go"
{
    echo '//go:build asspp_embedded && darwin && !ios'
    echo
    echo '// Added by asspp-attest (scripts/fetch-ipatool.sh): a copy of library_ios.go'
    echo '// for the macOS framework, which links Unicorn statically.'
    echo
    cat "$unicorn/library_ios.go"
} > "$unicorn/library_asspp_embedded.go"

mkdir -p "$dir/cmd/asspp-attestd"
cp "$root"/attestd/*.go "$dir/cmd/asspp-attestd/"
echo "$commit"
