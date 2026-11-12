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

## Two ways to run it

**macOS, Linux, a NAS: the HTTP service.**

```sh
./asspp-attestd-darwin-arm64 serve        # 127.0.0.1:18765
./asspp-attestd-linux-amd64 serve --listen 192.168.50.11:18765 --state-dir /data/state
```

On first start it generates an API token, saves it as `<state-dir>/token` and
prints it once. Point the client at it, for the fork's macOS build:

```sh
defaults write wiki.qaq.Asspp AttestationServiceURL http://127.0.0.1:18765
defaults write wiki.qaq.Asspp AttestationServiceToken <token>
```

State is one file per device GUID in `--state-dir` (default
`~/Library/Application Support/asspp-attestd` on macOS,
`$XDG_CONFIG_HOME/asspp-attestd` on Linux), mode 0600. Apple's components and
libunicorn go to ipatool's cache directory.

**iOS: `AssppAttest.framework` inside the app.** Sideloaded apps cannot start
helper processes, so the plugin runs in-process with an interpreter-only
Unicorn (no JIT, works on a stock iPhone). Add the framework to a client IPA
when you sign it:

- with your signing tool's framework or dylib injection, or
- with `scripts/inject-ipa.sh Asspp.ipa AssppAttest.framework Asspp-attest.ipa`,
  then sign as usual.

The first sign-in downloads Apple's components once (they take about 170 MB
in the cache) and takes a few minutes. After that, each sign-in and each
download request spends some seconds in the emulator.

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

The iOS framework (`embedded/build-runtime.sh`) needs Xcode, CMake and the
Unicorn sources from `scripts/fetch-unicorn.sh`. CI
([`framework.yml`](.github/workflows/framework.yml)) builds both slices and
runs the plugin in an iOS simulator; pushing a `v*` tag publishes a release.

## Layout

- `attestd/`: the Go program (HTTP service; with `-tags asspp_embedded`, the
  in-process plugin)
- `embedded/`: plugin header, framework build script, simulator harness
- `scripts/`: fetch pinned sources, inject the framework into an IPA
- `docs/PROTOCOL.md`: the protocol a client implements
