package main

import "net/http"

// pluginAPI is the major version of the protocol in docs/PROTOCOL.md. It
// changes only when an existing method or field changes meaning.
const pluginAPI = 1

const homepage = "https://github.com/eric1932/asspp-attest"

// capabilities lists the attestation methods this build implements.
var capabilities = []string{"machine-headers", "provision", "store-headers", "kbsync"}

// info describes this plugin, so a client can tell the user what it loaded and
// under which license, and skip what is not implemented.
func (s *server) info(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"api":           pluginAPI,
		"id":            "asspp-attest",
		"name":          "asspp-attest",
		"version":       version,
		"license":       "GPL-2.0-only",
		"homepage":      homepage,
		"ipatoolCommit": ipatoolCommit,
		"capabilities":  capabilities,
	})
}
