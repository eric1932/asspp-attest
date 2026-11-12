#!/bin/bash
# Builds AssppAttest.framework for one Apple SDK.
#
# The framework is one dynamic library holding the embedded asspp-attestd (a Go
# c-archive built inside the pinned ipatool tree) and an interpreter-only
# Unicorn with the aarch64 guest. It never maps executable memory, so it runs
# on a stock iPhone and in a Mac app without a JIT entitlement. It exports only
# the plugin entry point and the Unicorn API, which ipatool finds through
# dlsym(RTLD_DEFAULT).
#
#   build-runtime.sh <ipatool-dir> <unicorn-source-dir> <out-dir> <sdk> <triple> [version] [ipatool-commit]
#
# <ipatool-dir> comes from scripts/fetch-ipatool.sh. <sdk> is iphoneos,
# iphonesimulator or macosx; <triple> for example arm64-apple-ios16.0,
# arm64-apple-ios16.0-simulator or arm64-apple-macos15.0.
set -euo pipefail

ipatool="$(cd "$1" && pwd)"
unicorn="$(cd "$2" && pwd)"
mkdir -p "$3"
out="$(cd "$3" && pwd)"
sdk="$4"
triple="$5"
version="${6:-dev}"
commit="${7:-unknown}"
here="$(cd "$(dirname "$0")" && pwd)"

sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
cc="$(xcrun --sdk "$sdk" --find clang)"
work="$out/work"
mkdir -p "$work"

case "$sdk" in
    iphoneos)
        platform=iPhoneOS goos=ios cmake_system=iOS
        minimum_key=MinimumOSVersion minimum=16.0 ;;
    iphonesimulator)
        platform=iPhoneSimulator goos=ios cmake_system=iOS
        minimum_key=MinimumOSVersion minimum=16.0 ;;
    macosx)
        platform=MacOSX goos=darwin cmake_system=Darwin
        minimum_key=LSMinimumSystemVersion minimum=15.0 ;;
    *) echo "unsupported sdk: $sdk" >&2; exit 2 ;;
esac

cmake -S "$unicorn" -B "$work/unicorn" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME="$cmake_system" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="$sysroot" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$minimum" \
    -DCMAKE_C_COMPILER="$cc" \
    -DCMAKE_C_COMPILER_TARGET="$triple" \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DUNICORN_INTERPRETER=ON \
    -DUNICORN_ARCH=aarch64 \
    -DUNICORN_BUILD_TESTS=OFF \
    -DUNICORN_INSTALL=OFF \
    -DBUILD_SHARED_LIBS=OFF
grep -q '#define CONFIG_TCG_INTERPRETER 1' "$work/unicorn/config-host.h" || {
    echo "refusing a Unicorn build that generates executable code" >&2
    exit 1
}
cmake --build "$work/unicorn" --parallel 4
test -f "$work/unicorn/libunicorn.a"

(
    cd "$ipatool"
    export CGO_ENABLED=1 GOOS="$goos" GOARCH=arm64 CC="$cc"
    export CGO_CFLAGS="-target $triple -isysroot $sysroot"
    export CGO_LDFLAGS="-target $triple -isysroot $sysroot"
    go build -trimpath -tags asspp_embedded -buildmode=c-archive \
        -ldflags "-s -w -X main.version=$version -X main.ipatoolCommit=$commit" \
        -o "$work/attestd.a" ./cmd/asspp-attestd
)

# Info.plist wants a numeric version; a commit hash goes into the binary only.
bundle_version="${version#v}"
[[ "$bundle_version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || bundle_version="0.0.0"

framework="$out/AssppAttest.framework"
rm -rf "$framework"
if [ "$platform" = MacOSX ]; then
    # macOS frameworks are versioned bundles.
    contents="$framework/Versions/A"
    resources="$contents/Resources"
    install_name=@rpath/AssppAttest.framework/Versions/A/AssppAttest
else
    contents="$framework"
    resources="$framework"
    install_name=@rpath/AssppAttest.framework/AssppAttest
fi
mkdir -p "$contents/Headers" "$contents/Modules" "$resources"

"$cc" -dynamiclib -target "$triple" -isysroot "$sysroot" \
    -Wl,-force_load,"$work/attestd.a" \
    -Wl,-force_load,"$work/unicorn/libunicorn.a" \
    -Wl,-exported_symbol,_asspp_attestation_plugin_v1 \
    -Wl,-exported_symbol,'_uc_*' \
    -framework CoreFoundation -framework Security -lresolv \
    -install_name "$install_name" \
    -o "$contents/AssppAttest"

cp "$here/AssppAttestPlugin.h" "$contents/Headers/"
cat > "$contents/Modules/module.modulemap" <<'EOF'
framework module AssppAttest {
    header "AssppAttestPlugin.h"
    export *
}
EOF
cat > "$resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AssppAttest</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.eric1932.AssppAttest</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AssppAttest</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$bundle_version</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>$platform</string>
    </array>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>$minimum_key</key>
    <string>$minimum</string>
</dict>
</plist>
EOF

if [ "$platform" = MacOSX ]; then
    ln -s A "$framework/Versions/Current"
    for item in AssppAttest Headers Modules Resources; do
        ln -s "Versions/Current/$item" "$framework/$item"
    done
    # Ad-hoc signed so it loads as is; a signing tool re-signs it when it goes into an app.
    codesign --force --sign - "$framework"
fi

# The plugin entry point and the Unicorn API (looked up by ipatool) must be
# visible to dlsym; the Go functions behind the table must not be.
exported="$(nm -gU "$contents/AssppAttest" | awk '{print $NF}')"
for symbol in _asspp_attestation_plugin_v1 _uc_version _uc_open _uc_ctl _uc_emu_start; do
    grep -qx "$symbol" <<<"$exported" || { echo "missing exported symbol: $symbol" >&2; exit 1; }
done
if grep -q '^_asb_' <<<"$exported"; then
    echo "internal asb_* symbols are exported" >&2
    exit 1
fi

file "$contents/AssppAttest"
ls -l "$contents/AssppAttest"
