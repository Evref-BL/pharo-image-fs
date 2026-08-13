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
		_, _ = response.Write([]byte(`{"entries":[{"name":"PharoImageFS","kind":"directory"}]}`))
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
	if len(entries) != 1 || entries[0].Name != "PharoImageFS" || entries[0].Kind != Directory {
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

	_, err = client.Read(t.Context(), "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if err == nil {
		t.Fatal("expected protocol error")
	}
	if err.Error() != "compile failed" {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestHTTPClientDeletePostsProjectionPath(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/projection/delete" {
			t.Fatalf("unexpected path: %s", request.URL.Path)
		}

		var body pathRequest
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if body.Path != "/tonel/PharoImageFS/Old.class.st" {
			t.Fatalf("unexpected projection path: %s", body.Path)
		}

		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{}`))
	}))
	defer server.Close()

	client, err := NewHTTPClient(server.URL + "/projection")
	if err != nil {
		t.Fatal(err)
	}

	if err := client.Delete(t.Context(), "/tonel/PharoImageFS/Old.class.st"); err != nil {
		t.Fatal(err)
	}
}

func TestHTTPClientRenamePostsSourceAndTargetPath(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/projection/rename" {
			t.Fatalf("unexpected path: %s", request.URL.Path)
		}

		var body renameRequest
		if err := json.NewDecoder(request.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if body.Path != "/tonel/PharoImageFS/Old.class.st" {
			t.Fatalf("unexpected projection path: %s", body.Path)
		}
		if body.TargetPath != "/tonel/PharoImageFS/New.class.st" {
			t.Fatalf("unexpected target projection path: %s", body.TargetPath)
		}

		response.Header().Set("Content-Type", "application/json")
		_, _ = response.Write([]byte(`{}`))
	}))
	defer server.Close()

	client, err := NewHTTPClient(server.URL + "/projection")
	if err != nil {
		t.Fatal(err)
	}

	if err := client.Rename(t.Context(), "/tonel/PharoImageFS/Old.class.st", "/tonel/PharoImageFS/New.class.st"); err != nil {
		t.Fatal(err)
	}
}
