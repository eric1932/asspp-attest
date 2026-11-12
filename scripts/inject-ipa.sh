#!/bin/bash
# Copies AssppAttest.framework into an Asspp IPA, for your own device.
#
#   scripts/inject-ipa.sh <Asspp.ipa> <AssppAttest.framework> <out.ipa>
#
# The result is unsigned; sign it with your usual tool. Asspp builds that know
# the plugin protocol load the framework from their Frameworks folder; no load
# command is added to the app. Sideloading tools that inject frameworks
# themselves (and add a load command) work too.
#
# Keep the result to yourself. Asspp includes Apache-2.0 code and this framework
# is GPL-2.0-only; a binary that combines them should not be redistributed.
set -euo pipefail

ipa="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
framework="$(cd "$2" && pwd)"
out="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"

test -f "$framework/AssppAttest" || { echo "not an AssppAttest.framework: $2" >&2; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

ditto -x -k "$ipa" "$work"
apps=("$work"/Payload/*.app)
test -d "${apps[0]}" || { echo "no Payload/*.app in $1" >&2; exit 2; }
app="${apps[0]}"

mkdir -p "$app/Frameworks"
rm -rf "$app/Frameworks/AssppAttest.framework"
ditto "$framework" "$app/Frameworks/AssppAttest.framework"
rm -rf "$app/Frameworks/AssppAttest.framework/Headers" "$app/Frameworks/AssppAttest.framework/Modules"

rm -f "$out"
(cd "$work" && ditto -c -k --keepParent --norsrc Payload "$out.tmp")
mv "$out.tmp" "$out"
echo "wrote $out"
