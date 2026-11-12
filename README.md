# asspp-attest

Device attestation for [Asspp](https://github.com/Lakr233/Asspp)-style App
Store clients, as a separate, opt-in, GPL-2.0 plugin.

Since about 2026-11-06 Apple's Store wants device attestation at sign-in
(anisette machine headers, Store provisioning, `X-Apple-AMD` proof) and a
`kbsync` blob for full downloads. asspp-attest produces them by running Apple's
own code in an emulator, using [ipatool](https://github.com/majd/ipatool)'s
implementation. It speaks a small [protocol](docs/PROTOCOL.md), so a client
only needs the protocol, not this code.

**Not affiliated with Asspp, its author, ipatool or Apple.** Asspp itself does
not accept emulation; this plugin works with clients that implement the
protocol, today the [eric1932/Asspp](https://github.com/eric1932/Asspp) fork.

## Install

**iPhone and iPad: inject `AssppAttest-iOS.framework` when you sign.**
Sideloaded apps cannot start helper processes, so the plugin runs inside the
app with an interpreter-only Unicorn (no JIT, works on a stock iPhone). Add the
framework to a client IPA when you sign it:

- with your signing tool's framework or dylib injection, or
- with `scripts/inject-ipa.sh Asspp.ipa AssppAttest.framework Asspp-attest.ipa`,
  then sign as usual.

**Mac: drop `AssppAttest-macOS.framework` into the plugin folder.** Unzip it
to `~/Library/Application Support/Asspp/Plugins/AssppAttest.framework` (for a
sandboxed build, the same path inside
`~/Library/Containers/wiki.qaq.Asspp/Data`) and restart the app. If macOS
quarantined the download, run
`xattr -dr com.apple.quarantine ~/Library/Application\ Support/Asspp/Plugins`.
A build with library validation turned on refuses plugins it did not sign;
the fork's local builds do not turn it on.

The first sign-in downloads Apple's components once (about 240 MB; around a
minute on CI, longer on a slow connection). After that, each sign-in and each
download request spends some seconds in the emulator (kbsync takes about 9 s
on CI's Macs and in the iOS simulator).

**Optional: the HTTP service, for a NAS or a Linux box.**

```sh
./asspp-attestd-linux-amd64 serve --listen 192.168.50.11:18765 --state-dir /data/state
```

On first start it generates an API token, saves it as `<state-dir>/token` and
prints it once. A client set to use it (`AttestationServiceURL` and
`AttestationServiceToken` in the fork) falls back to it when no plugin is
loaded. State is one file per device GUID in `--state-dir`, mode 0600.

## Licensing

asspp-attest is GPL-2.0-only because it contains Unicorn. Asspp is MIT but
links Apache-2.0 packages, and Apache-2.0 code cannot be combined with
GPL-2.0-only code in one distributed binary. So releases here contain only
the plugin, and the client stays a separate download. **Do not redistribute an
IPA with the framework inside**; combine them on your own device. This is not
legal advice. See [NOTICES.md](NOTICES.md) for third-party components.

Apple's components are never in this repository or in a release; they are
downloaded from Apple on the device that uses them.

## Build

attestd imports ipatool's internal packages, so it is built inside an ipatool
checkout at `IPATOOL_COMMIT`:

```sh
scripts/fetch-ipatool.sh build/ipatool
(cd build/ipatool && go test ./cmd/asspp-attestd && go build -o ../../asspp-attestd ./cmd/asspp-attestd)
```

The framework (`embedded/build-runtime.sh`, iOS, iOS Simulator and macOS slices) needs Xcode, CMake and the
Unicorn sources from `scripts/fetch-unicorn.sh`. CI
([`framework.yml`](.github/workflows/framework.yml)) builds the slices and
runs the plugin on macOS and in an iOS simulator; pushing a `v*` tag publishes a release.

## Layout

- `attestd/`: the Go program (HTTP service; with `-tags asspp_embedded`, the
  in-process plugin)
- `embedded/`: plugin header, framework build script, simulator harness
- `scripts/`: fetch pinned sources, inject the framework into an IPA
- `docs/PROTOCOL.md`: the protocol a client implements
