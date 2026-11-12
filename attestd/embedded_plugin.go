//go:build asspp_embedded

package main

// The plugin entry point, declared in embedded/AssppAttestPlugin.h. It is the
// only symbol a host looks up (besides the Unicorn API that ipatool finds with
// dlsym), so two injected plugins cannot clash over function names.
//
// cgo forbids definitions in the preamble of a file with //export, so the
// table lives here and the functions it points to in embedded_cgo.go.

/*
#include <stdint.h>

extern int32_t asb_configure(char *stateDir);
extern int32_t asb_call(char *method, uint8_t *request, uint64_t requestLength,
                        uint64_t cancelToken, uint8_t **response, uint64_t *responseLength);
extern void asb_cancel(uint64_t cancelToken);
extern void asb_free(void *pointer);

typedef struct AssppAttestationPluginV1 {
    uint32_t size;
    uint32_t api;
    int32_t (*configure)(const char *state_dir);
    int32_t (*call)(const char *method, const uint8_t *request, uint64_t request_length,
                    uint64_t cancel_token, uint8_t **response, uint64_t *response_length);
    void (*cancel)(uint64_t cancel_token);
    void (*release)(void *pointer);
} AssppAttestationPluginV1;

static int32_t plugin_configure(const char *state_dir) {
    return asb_configure((char *)state_dir);
}

static int32_t plugin_call(const char *method, const uint8_t *request, uint64_t request_length,
                           uint64_t cancel_token, uint8_t **response, uint64_t *response_length) {
    return asb_call((char *)method, (uint8_t *)request, request_length, cancel_token, response, response_length);
}

static const AssppAttestationPluginV1 plugin = {
    .size = sizeof(AssppAttestationPluginV1),
    .api = 1,
    .configure = plugin_configure,
    .call = plugin_call,
    .cancel = asb_cancel,
    .release = asb_free,
};

__attribute__((visibility("default"), used))
const AssppAttestationPluginV1 *asspp_attestation_plugin_v1(void) {
    return &plugin;
}
*/
import "C"
