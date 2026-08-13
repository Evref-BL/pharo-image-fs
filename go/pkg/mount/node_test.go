package mount

import (
	"bytes"
	"context"
	"log"
	"net/http"
	"strings"
	"syscall"
	"testing"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
)

func TestRootReaddirUsesProjectionClient(t *testing.T) {
	client := &fakeClient{
		entries: map[string][]protocol.Entry{
			"/": {
				{Name: "tonel", Kind: protocol.Directory},
				{Name: "critiques", Kind: protocol.Directory},
			},
		},
	}
	root := NewRoot(client)

	stream, errno := root.Readdir(t.Context())
	if errno != 0 {
		t.Fatalf("readdir errno: %v", errno)
	}

	names := dirStreamNames(t, stream)
	if len(names) != 2 || names[0] != "tonel" || names[1] != "critiques" {
		t.Fatalf("unexpected entries: %#v", names)
	}
}

func TestTonelDirectoriesAreWritableForEditorTempFiles(t *testing.T) {
	client := &fakeClient{
		stats: map[string]protocol.Entry{
			"/tonel": {
				Name: "tonel",
				Kind: protocol.Directory,
			},
		},
	}
	root := NewRoot(client)
	fs.NewNodeFS(root, nil)

	var out fuse.EntryOut
	_, errno := root.Lookup(t.Context(), "tonel", &out)
	if errno != 0 {
		t.Fatalf("lookup errno: %v", errno)
	}

	if out.Attr.Mode&0o200 == 0 {
		t.Fatalf("expected writable tonel directory mode, got %#o", out.Attr.Mode)
	}
}

func TestCreateReaddirAndUnlinkUseOverlay(t *testing.T) {
	client := &fakeClient{}
	node := writableTonelDirectoryNode(client)

	var out fuse.EntryOut
	_, handle, _, errno := node.Create(t.Context(), ".PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644, &out)
	if errno != 0 {
		t.Fatalf("create errno: %v", errno)
	}

	if _, errno := handle.(*FileHandle).Write(t.Context(), []byte("temporary contents"), 0); errno != 0 {
		t.Fatalf("write errno: %v", errno)
	}
	if errno := handle.(*FileHandle).Flush(t.Context()); errno != 0 {
		t.Fatalf("flush errno: %v", errno)
	}

	stream, errno := node.Readdir(t.Context())
	if errno != 0 {
		t.Fatalf("readdir errno: %v", errno)
	}

	names := dirStreamNames(t, stream)
	if len(names) != 1 || names[0] != ".PharoImageFSProjectionBackend.class.st.tmp" {
		t.Fatalf("unexpected entries: %#v", names)
	}

	if errno := node.Unlink(t.Context(), ".PharoImageFSProjectionBackend.class.st.tmp"); errno != 0 {
		t.Fatalf("unlink errno: %v", errno)
	}
}

func TestRenameOverlayFileToTonelFileWritesProjection(t *testing.T) {
	client := &fakeClient{
		stats: map[string]protocol.Entry{
			"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st": {
				Name:     "PharoImageFSProjectionBackend.class.st",
				Kind:     protocol.File,
				Writable: true,
			},
		},
	}
	node := writableTonelDirectoryNode(client)

	var out fuse.EntryOut
	_, handle, _, errno := node.Create(t.Context(), ".PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644, &out)
	if errno != 0 {
		t.Fatalf("create errno: %v", errno)
	}

	if _, errno := handle.(*FileHandle).Write(t.Context(), []byte("updated source"), 0); errno != 0 {
		t.Fatalf("write errno: %v", errno)
	}
	if errno := handle.(*FileHandle).Flush(t.Context()); errno != 0 {
		t.Fatalf("flush errno: %v", errno)
	}

	errno = node.Rename(
		t.Context(),
		".PharoImageFSProjectionBackend.class.st.tmp",
		node,
		"PharoImageFSProjectionBackend.class.st",
		0)
	if errno != 0 {
		t.Fatalf("rename errno: %v", errno)
	}

	if client.writtenPath != "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" {
		t.Fatalf("unexpected written path: %s", client.writtenPath)
	}
	if string(client.writtenContents) != "updated source" {
		t.Fatalf("unexpected written contents: %q", client.writtenContents)
	}
}

func TestRenameOverlayFileToTonelFileLogsDiagnostics(t *testing.T) {
	logBuffer := bytes.Buffer{}
	client := &fakeClient{
		stats: map[string]protocol.Entry{
			"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st": {
				Name:     "PharoImageFSProjectionBackend.class.st",
				Kind:     protocol.File,
				Writable: true,
			},
		},
		writeResult: protocol.WriteResult{
			Diagnostics: []protocol.Diagnostic{
				{
					Rule:     "ReDeadBlockRule",
					Severity: "error",
					Title:    "Dead block",
					Message:  "outer block will not compile as intended",
				},
			},
		},
	}
	node := writableTonelDirectoryNode(client)
	node.logger = log.New(&logBuffer, "", 0)

	var out fuse.EntryOut
	_, handle, _, errno := node.Create(t.Context(), ".PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644, &out)
	if errno != 0 {
		t.Fatalf("create errno: %v", errno)
	}

	if _, errno := handle.(*FileHandle).Write(t.Context(), []byte("updated source"), 0); errno != 0 {
		t.Fatalf("write errno: %v", errno)
	}
	if errno := handle.(*FileHandle).Flush(t.Context()); errno != 0 {
		t.Fatalf("flush errno: %v", errno)
	}

	errno = node.Rename(
		t.Context(),
		".PharoImageFSProjectionBackend.class.st.tmp",
		node,
		"PharoImageFSProjectionBackend.class.st",
		0)
	if errno != 0 {
		t.Fatalf("rename errno: %v", errno)
	}

	logText := logBuffer.String()
	if !strings.Contains(logText, "write /tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st returned 1 diagnostic(s)") {
		t.Fatalf("missing diagnostic count log: %s", logText)
	}
	if !strings.Contains(logText, "diagnostic ReDeadBlockRule: error - Dead block - outer block will not compile as intended") {
		t.Fatalf("missing diagnostic detail log: %s", logText)
	}
}

func TestRenameOverlayFileToTonelFileLogsWriteFailure(t *testing.T) {
	logBuffer := bytes.Buffer{}
	client := &fakeClient{
		stats: map[string]protocol.Entry{
			"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st": {
				Name:     "PharoImageFSProjectionBackend.class.st",
				Kind:     protocol.File,
				Writable: true,
			},
		},
		writeErr: &protocol.Error{
			StatusCode: http.StatusBadRequest,
			Message:    "compile failed",
		},
	}
	node := writableTonelDirectoryNode(client)
	node.logger = log.New(&logBuffer, "", 0)

	var out fuse.EntryOut
	_, handle, _, errno := node.Create(t.Context(), ".PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644, &out)
	if errno != 0 {
		t.Fatalf("create errno: %v", errno)
	}

	if _, errno := handle.(*FileHandle).Write(t.Context(), []byte("broken source"), 0); errno != 0 {
		t.Fatalf("write errno: %v", errno)
	}
	if errno := handle.(*FileHandle).Flush(t.Context()); errno != 0 {
		t.Fatalf("flush errno: %v", errno)
	}

	errno = node.Rename(
		t.Context(),
		".PharoImageFSProjectionBackend.class.st.tmp",
		node,
		"PharoImageFSProjectionBackend.class.st",
		0)
	if errno != syscall.EIO {
		t.Fatalf("unexpected rename errno: %v", errno)
	}

	logText := logBuffer.String()
	if !strings.Contains(logText, "write /tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st failed: compile failed") {
		t.Fatalf("missing failure log: %s", logText)
	}
}

func TestUnlinkProjectedTonelFileUsesProjectionProtocol(t *testing.T) {
	client := &fakeClient{}
	node := writableTonelDirectoryNode(client)

	errno := node.Unlink(t.Context(), "PharoImageFSProjectionBackend.class.st")
	if errno != 0 {
		t.Fatalf("unlink errno: %v", errno)
	}

	if client.deletedPath != "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" {
		t.Fatalf("unexpected deleted path: %s", client.deletedPath)
	}
}

func TestRenameProjectedTonelFileUsesProjectionProtocol(t *testing.T) {
	client := &fakeClient{}
	node := writableTonelDirectoryNode(client)

	errno := node.Rename(
		t.Context(),
		"Old.class.st",
		node,
		"New.class.st",
		0)
	if errno != 0 {
		t.Fatalf("rename errno: %v", errno)
	}

	if client.renamedPath != "/tonel/PharoImageFS/Old.class.st" {
		t.Fatalf("unexpected renamed path: %s", client.renamedPath)
	}
	if client.renameTarget != "/tonel/PharoImageFS/New.class.st" {
		t.Fatalf("unexpected rename target: %s", client.renameTarget)
	}
}

func writableTonelDirectoryNode(client protocol.Client) *Node {
	root := NewRoot(client)
	fs.NewNodeFS(root, nil)

	entry := protocol.Entry{
		Name:     "PharoImageFS",
		Kind:     protocol.Directory,
		Writable: true,
	}
	node := root.childNode("/tonel/PharoImageFS", entry)
	root.NewInode(context.Background(), node, stableAttrFor(entry))
	return node
}
