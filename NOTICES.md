# Third-party notices

asspp-attest is GPL-2.0-only (see LICENSE). It builds on:

- **ipatool** by Majd Alfhaily, MIT. attestd is compiled inside an ipatool
  checkout at `IPATOOL_COMMIT` and calls its internal `storeauth`,
  `sap/assets` and `sap/machine` packages. https://github.com/majd/ipatool
- **Unicorn** (and the QEMU code inside it), GPL-2.0. The HTTP service loads
  libunicorn at runtime as ipatool does. The iOS framework statically links an
  interpreter-only build of `1rhino2/unicorn-tci`, with `qemu/target` from
  `unicorn-engine/unicorn`; `scripts/fetch-unicorn.sh` pins both, and every
  release attaches the exact sources as `unicorn-source.tar.gz`.
- **Go** standard library and runtime, BSD-3-Clause.

Apple's components (the macOS frameworks the emulator runs) are downloaded
from Apple's servers on the user's device at first use. They are not part of
this repository or of any release.

This project is not affiliated with Apple, with Asspp or its author, or with
ipatool.
