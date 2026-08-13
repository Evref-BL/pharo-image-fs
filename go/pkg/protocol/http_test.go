package protocol

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHTTPClientListPostsProjectionPath(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/projection/list" {
			t.Fatalf("unexpected path: %s", request.URL.Path)
		}

		var body pathRequest
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if body.Path != "/tonel" {
			t.Fatalf("unexpected projection path: %s", body.Path)
		}

		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{"entries":[{"name":"MCP","kind":"directory"}]}`))
	}))
	defer server.Close()

	client, err := NewHTTPClient(server.URL + "/projection")
	if err != nil {
		t.Fatal(err)
	}

	entries, err := client.List(t.Context(), "/tonel")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Name != "MCP" || entries[0].Kind != Directory {
		t.Fatalf("unexpected entries: %#v", entries)
	}
}

func TestHTTPClientReturnsProtocolErrorMessage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		response.WriteHeader(http.StatusBadRequest)
		_, _ = response.Write([]byte(`{"message":"compile failed"}`))
	}))
	defer server.Close()

	client, err := NewHTTPClient(server.URL)
	if err != nil {
		t.Fatal(err)
	}

	_, err = client.Read(t.Context(), "/tonel/MCP/MCP.class.st")
	if err == nil {
		t.Fatal("expected protocol error")
	}
	if err.Error() != "compile failed" {
		t.Fatalf("unexpected error: %v", err)
	}
}
