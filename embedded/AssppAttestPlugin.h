// asspp-attest plugin ABI, version 1. See ../docs/PROTOCOL.md.
//
// A plugin is a library that exports one function, asspp_attestation_plugin_v1,
// returning a table of four functions. A host (Asspp) finds it with
// dlsym(RTLD_DEFAULT, ...) after the library is loaded, either because it was
// injected into the app at signing time or because the host dlopen'ed it from
// its Frameworks folder.
//
// The methods and JSON bodies are the same as the HTTP API, without a listener
// or a token. All functions are thread-safe. call blocks for seconds, or for
// minutes the first time while Apple's components are downloaded, so call it
// off the main thread. "health" and "info" answer while another call runs.

#ifndef ASSPP_ATTEST_PLUGIN_H
#define ASSPP_ATTEST_PLUGIN_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AssppAttestationPluginV1 {
    // sizeof(AssppAttestationPluginV1) as built by the plugin. Later versions
    // only append fields, so a host reads the fields it knows when size allows.
    uint32_t size;

    // 1 for this layout and protocol version.
    uint32_t api;

    // Sets the directory that holds the plugin's state (one file per device).
    // An absolute path, created if needed. Call once before call. Returns 0 on
    // success.
    int32_t (*configure)(const char *state_dir);

    // Runs one method: "info", "health", "prepare", "machine-headers",
    // "provision", "store-headers" or "kbsync". `request` is the method's JSON
    // body, or NULL.
    //
    // Returns 0 on success, with the method's JSON in *response. Otherwise
    // returns the HTTP status the service would have sent, with
    // {"code","message"} JSON in *response. *response is always set and must be
    // released with release.
    //
    // `cancel_token` is a non-zero value the caller picks, unique among running
    // calls, that cancel can use to stop this call. Pass 0 for a call that
    // cannot be canceled.
    int32_t (*call)(const char *method,
                    const uint8_t *request, uint64_t request_length,
                    uint64_t cancel_token,
                    uint8_t **response, uint64_t *response_length);

    // Stops the call started with this token. Safe from any thread, more than
    // once, and after the call has finished.
    void (*cancel)(uint64_t cancel_token);

    // Releases a buffer returned by call.
    void (*release)(void *pointer);
} AssppAttestationPluginV1;

// The only entry point. Returns a table that stays valid for the life of the
// process.
const AssppAttestationPluginV1 *asspp_attestation_plugin_v1(void);

#ifdef __cplusplus
}
#endif

#endif
