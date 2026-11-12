package main

import (
	"net/http"
	"testing"
)

func TestInfoDescribesThePlugin(t *testing.T) {
	srv, _ := newTestServer(t, &fakeBackend{})

	recorder, body := call(t, srv, http.MethodGet, "/v1/info", nil, testToken)
	if recorder.Code != http.StatusOK {
		t.Fatalf("info: %d %v", recorder.Code, body)
	}

	if body["api"] != float64(pluginAPI) || body["license"] != "GPL-2.0-only" || body["id"] != "asspp-attest" {
		t.Fatalf("info: %v", body)
	}

	got, _ := body["capabilities"].([]any)
	if len(got) != len(capabilities) {
		t.Fatalf("capabilities: %v", body["capabilities"])
	}

	recorder, _ = call(t, srv, http.MethodGet, "/v1/info", nil, "")
	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("info without a token: %d", recorder.Code)
	}
}

func TestEmbeddedInfoNeedsNoToken(t *testing.T) {
	var service embedded
	if err := service.configure(t.TempDir(), &fakeBackend{}); err != nil {
		t.Fatal(err)
	}

	status, body := service.call("info", nil, 0)
	if status != http.StatusOK || decodeEmbedded(t, body)["api"] != float64(pluginAPI) {
		t.Fatalf("info: %d %s", status, body)
	}
}
