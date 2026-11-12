# Attestation plugin protocol, version 1

How Asspp (or any client) asks a plugin for the device attestation Apple's
Store started requiring around 2026-11-06. The same methods and JSON bodies go
over two transports: HTTP to a separate process, or a C function table inside
the app.

A plugin never sees the Apple ID password or a verification code. It keeps its
own state (machine and Store provisioning), one record per device GUID.

## Methods

A method takes a JSON object and returns a JSON object. Errors are
`{"code", "message"}` with an HTTP-style status.

| Method | Request | Response |
|---|---|---|
| `info` | | `api` (1), `id`, `name`, `version`, `license`, `homepage`, `capabilities` |
| `health` | | `assetsCached`, `assetBytes`, plus implementation details |
| `prepare` | `{}` | `{}` once Apple's components are ready |
| `machine-headers` | `guid` | `headers`: anisette machine headers; drops any Store provisioning for the device |
| `provision` | `guid, challenge, endpoint, userAgent, machineHeaders, cookies` | `cookies` Apple set during Store provisioning |
| `store-headers` | `guid, url` | `headers`: `X-Apple-AMD`, `X-Apple-AMD-M` for that URL |
| `kbsync` | `guid, dsid` (decimal string) | `kbsync` (base64) |

- `guid` is the client's 12-hex-digit device identifier.
- `capabilities` lists which of the last four methods the plugin implements.
  A client should not call the others.
- `info` and `health` answer while another call runs, so a client can poll
  `health` for progress. `assetBytes` counts the bytes of Apple's components
  downloaded so far; it grows during the first call after install and stays put
  once `assetsCached` is true.

| Code | Status | Meaning |
|---|---|---|
| `invalid_request` | 400 | malformed body or unknown method |
| `unauthorized` | 401 | HTTP only: missing or wrong token |
| `not_provisioned` | 409 | no Store provisioning for this device yet; sign in again |
| `canceled` | 499 | the caller canceled |
| `emulator_failed` | 500 | the plugin failed internally |
| `upstream_failed` | 502 | Apple answered with an error |
| `assets_unavailable` | 503 | Apple's components could not be downloaded |
| `not_configured` | 503 | in-process only: `configure` was not called |

## HTTP transport

`GET /v1/info`, `GET /v1/health`, `POST /v1/<method>` with a JSON body.
Every request needs `Authorization: Bearer <token>`. Listen on localhost by
default: `provision` carries Store session cookies and `kbsync` carries the
DSID, so use it across a network only over TLS or a network you trust.

## In-process transport (iOS)

The library exports one function, declared in
[`embedded/AssppAttestPlugin.h`](../embedded/AssppAttestPlugin.h):

```c
const AssppAttestationPluginV1 *asspp_attestation_plugin_v1(void);
```

It returns a table: `size`, `api` (1), then `configure(state_dir)`,
`call(method, request, length, cancel_token, &response, &response_length)`,
`cancel(token)` and `release(pointer)`. On 64-bit platforms the four function
pointers sit at byte offsets 8, 16, 24 and 32. `call` returns 0 on success and
otherwise the HTTP status from the table above; the response buffer is always
set and must be released with `release`.

A host finds the function with `dlsym(RTLD_DEFAULT, "asspp_attestation_plugin_v1")`.
If the library was not loaded at launch, the host `dlopen`s
`Frameworks/AssppAttest.framework/AssppAttest` from its own bundle with
`RTLD_NOW | RTLD_GLOBAL` first. `RTLD_GLOBAL` matters for this plugin: ipatool
finds the Unicorn API with `dlsym(RTLD_DEFAULT, ...)`.

Stock iOS cannot load native code downloaded at runtime, so an in-process
plugin is either injected into the IPA at signing time or built in.

## Versioning

`api` changes only when an existing method or field changes meaning. New
methods and fields can appear within version 1; clients ignore what they do
not know. The C table only grows at the end, and `size` says how much of it
the plugin filled in.
