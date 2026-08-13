package mount

import (
	"context"
	"net/http"
	"syscall"
	"testing"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
	"github.com/hanwen/go-fuse/v2/fs"
)

func TestFileHandleFlushWritesFullContents(t *testing.T) {
	client := &fakeClient{}
	handle := &FileHandle{
		client:   client,
		path:     "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st",
		contents: []byte("abc"),
		writable: true,
	}

	written, errno := handle.Write(t.Context(), []byte("XY"), 1)
	if errno != 0 {
		t.Fatalf("write errno: %v", errno)
	}
	if written != 2 {
		t.Fatalf("unexpected bytes written: %d", written)
	}

	if errno := handle.Flush(t.Context()); errno != 0 {
		t.Fatalf("flush errno: %v", errno)
	}

	if client.writtenPath != "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" {
		t.Fatalf("unexpected written path: %s", client.writtenPath)
	}
	if string(client.writtenContents) != "aXY" {
		t.Fatalf("unexpected written contents: %q", client.writtenContents)
	}
}

func TestFileHandleRejectsReadOnlyWrite(t *testing.T) {
	handle := &FileHandle{
		contents: []byte("diagnostics"),
		writable: false,
	}

	_, errno := handle.Write(t.Context(), []byte("x"), 0)
	if errno != syscall.EROFS {
		t.Fatalf("unexpected errno: %v", errno)
	}
}

type fakeClient struct {
	entries         map[string][]protocol.Entry
	stats           map[string]protocol.Entry
	writtenPath     string
	writtenContents []byte
}

func (c *fakeClient) List(_ context.Context, path string) ([]protocol.Entry, error) {
	return c.entries[path], nil
}

func (c *fakeClient) Stat(_ context.Context, path string) (protocol.Entry, error) {
	entry, ok := c.stats[path]
	if !ok {
		return protocol.Entry{}, &protocol.Error{StatusCode: http.StatusNotFound}
	}

	return entry, nil
}

func (c *fakeClient) Read(context.Context, string) ([]byte, error) {
	return nil, nil
}

func (c *fakeClient) Write(_ context.Context, path string, contents []byte) (protocol.WriteResult, error) {
	c.writtenPath = path
	c.writtenContents = append([]byte(nil), contents...)
	return protocol.WriteResult{}, nil
}

func dirStreamNames(t *testing.T, stream fs.DirStream) []string {
	t.Helper()

	names := []string{}
	for stream.HasNext() {
		entry, errno := stream.Next()
		if errno != 0 {
			t.Fatalf("dir stream errno: %v", errno)
		}
		names = append(names, entry.Name)
	}
	return names
}
