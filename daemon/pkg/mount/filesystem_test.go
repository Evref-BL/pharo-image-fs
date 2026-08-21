package mount

import (
	"bytes"
	"log"
	"net/http"
	"strings"
	"syscall"
	"testing"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
	"github.com/winfsp/cgofuse/fuse"
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
	fsys := NewProjectionFileSystem(client)

	names := []string{}
	errc := fsys.Readdir("/", func(name string, _ *fuse.Stat_t, _ int64) bool {
		names = append(names, name)
		return true
	}, 0, 0)
	if errc != 0 {
		t.Fatalf("readdir errno: %v", errc)
	}

	if strings.Join(names, ",") != ".,..,tonel,critiques,errors" {
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
	fsys := NewProjectionFileSystem(client)

	var stat fuse.Stat_t
	errc := fsys.Getattr("/tonel", &stat, 0)
	if errc != 0 {
		t.Fatalf("getattr errno: %v", errc)
	}

	if stat.Mode&0o200 == 0 {
		t.Fatalf("expected writable tonel directory mode, got %#o", stat.Mode)
	}
}

func TestCreateReaddirAndUnlinkUseOverlay(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	fsys := NewProjectionFileSystem(client)

	errc, handle := fsys.Create("/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644)
	if errc != 0 {
		t.Fatalf("create errno: %v", errc)
	}

	if written := fsys.Write("", []byte("temporary contents"), 0, handle); written != len("temporary contents") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	names := []string{}
	errc = fsys.Readdir("/tonel/PharoImageFS", func(name string, _ *fuse.Stat_t, _ int64) bool {
		names = append(names, name)
		return true
	}, 0, 0)
	if errc != 0 {
		t.Fatalf("readdir errno: %v", errc)
	}
	if !contains(names, ".PharoImageFSProjectionBackend.class.st.tmp") {
		t.Fatalf("missing overlay entry: %#v", names)
	}

	if errc := fsys.Unlink("/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp"); errc != 0 {
		t.Fatalf("unlink errno: %v", errc)
	}
}

func TestCreateProjectedTonelFileWritesProjectionOnFlush(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	fsys := NewProjectionFileSystem(client)

	errc, handle := fsys.Create("/tonel/PharoImageFS/NewClass.class.st", syscall.O_RDWR, 0o644)
	if errc != 0 {
		t.Fatalf("create errno: %v", errc)
	}

	if written := fsys.Write("", []byte("new source"), 0, handle); written != len("new source") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	if client.writtenPath != "/tonel/PharoImageFS/NewClass.class.st" {
		t.Fatalf("unexpected written path: %s", client.writtenPath)
	}
	if string(client.writtenContents) != "new source" {
		t.Fatalf("unexpected written contents: %q", client.writtenContents)
	}
	if _, ok := fsys.overlay.Stat("/tonel/PharoImageFS/NewClass.class.st"); ok {
		t.Fatalf("projected file stayed in overlay after successful write")
	}
}

func TestRenameOverlayFileToTonelFileWritesProjection(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	client.stats["/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st"] = protocol.Entry{
		Name:     "PharoImageFSProjectionBackend.class.st",
		Kind:     protocol.File,
		Writable: true,
	}
	fsys := NewProjectionFileSystem(client)

	errc, handle := fsys.Create("/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644)
	if errc != 0 {
		t.Fatalf("create errno: %v", errc)
	}

	if written := fsys.Write("", []byte("updated source"), 0, handle); written != len("updated source") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	errc = fsys.Rename(
		"/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp",
		"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if errc != 0 {
		t.Fatalf("rename errno: %v", errc)
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
	client := fakeProjectionClientForTonelPackage()
	client.stats["/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st"] = protocol.Entry{
		Name:     "PharoImageFSProjectionBackend.class.st",
		Kind:     protocol.File,
		Writable: true,
	}
	client.writeResult = protocol.WriteResult{
		Diagnostics: []protocol.Diagnostic{
			{
				Rule:     "ReDeadBlockRule",
				Severity: "error",
				Title:    "Dead block",
				Message:  "outer block will not compile as intended",
			},
		},
	}
	fsys := NewProjectionFileSystem(client)
	fsys.logger = log.New(&logBuffer, "", 0)

	errc, handle := fsys.Create("/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644)
	if errc != 0 {
		t.Fatalf("create errno: %v", errc)
	}

	if written := fsys.Write("", []byte("updated source"), 0, handle); written != len("updated source") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	errc = fsys.Rename(
		"/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp",
		"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if errc != 0 {
		t.Fatalf("rename errno: %v", errc)
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
	client := fakeProjectionClientForTonelPackage()
	client.stats["/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st"] = protocol.Entry{
		Name:     "PharoImageFSProjectionBackend.class.st",
		Kind:     protocol.File,
		Writable: true,
	}
	client.writeErr = &protocol.Error{
		StatusCode: http.StatusBadRequest,
		Message:    "compile failed",
	}
	fsys := NewProjectionFileSystem(client)
	fsys.logger = log.New(&logBuffer, "", 0)

	errc, handle := fsys.Create("/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644)
	if errc != 0 {
		t.Fatalf("create errno: %v", errc)
	}

	if written := fsys.Write("", []byte("broken source"), 0, handle); written != len("broken source") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	errc = fsys.Rename(
		"/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp",
		"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if errc != -int(syscall.EIO) {
		t.Fatalf("unexpected rename errno: %v", errc)
	}

	logText := logBuffer.String()
	if !strings.Contains(logText, "write /tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st failed: compile failed") {
		t.Fatalf("missing failure log: %s", logText)
	}
}

func TestRenameOverlayFileToTonelFileExposesLatestWriteError(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	client.stats["/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st"] = protocol.Entry{
		Name:     "PharoImageFSProjectionBackend.class.st",
		Kind:     protocol.File,
		Writable: true,
	}
	client.writeErr = &protocol.Error{
		StatusCode: http.StatusBadRequest,
		Message:    "Cannot parse Tonel file",
	}
	fsys := NewProjectionFileSystem(client)

	errc, handle := fsys.Create("/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp", syscall.O_RDWR, 0o644)
	if errc != 0 {
		t.Fatalf("create errno: %v", errc)
	}

	if written := fsys.Write("", []byte("broken source"), 0, handle); written != len("broken source") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	errc = fsys.Rename(
		"/tonel/PharoImageFS/.PharoImageFSProjectionBackend.class.st.tmp",
		"/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if errc != -int(syscall.EIO) {
		t.Fatalf("unexpected rename errno: %v", errc)
	}

	names := []string{}
	errc = fsys.Readdir("/errors", func(name string, _ *fuse.Stat_t, _ int64) bool {
		names = append(names, name)
		return true
	}, 0, 0)
	if errc != 0 {
		t.Fatalf("readdir errno: %v", errc)
	}
	if !contains(names, "latest.txt") {
		t.Fatalf("missing latest error entry: %#v", names)
	}

	errc, errorHandle := fsys.Open("/errors/latest.txt", syscall.O_RDONLY)
	if errc != 0 {
		t.Fatalf("open latest error errno: %v", errc)
	}
	buffer := make([]byte, 512)
	read := fsys.Read("", buffer, 0, errorHandle)
	if read < 0 {
		t.Fatalf("read latest error errno: %v", read)
	}
	errorText := string(buffer[:read])
	if !strings.Contains(errorText, "Operation: write") {
		t.Fatalf("missing operation: %s", errorText)
	}
	if !strings.Contains(errorText, "Path: /tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st") {
		t.Fatalf("missing path: %s", errorText)
	}
	if !strings.Contains(errorText, "Image changed: no") {
		t.Fatalf("missing image state: %s", errorText)
	}
	if !strings.Contains(errorText, "Cannot parse Tonel file") {
		t.Fatalf("missing Pharo error: %s", errorText)
	}
}

func TestUnlinkProjectedTonelFileUsesProjectionProtocol(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	fsys := NewProjectionFileSystem(client)

	errc := fsys.Unlink("/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if errc != 0 {
		t.Fatalf("unlink errno: %v", errc)
	}

	if client.deletedPath != "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" {
		t.Fatalf("unexpected deleted path: %s", client.deletedPath)
	}
}

func TestUnlinkProjectedTonelFileIgnoresProjectionNotFound(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	client.deleteErr = &protocol.Error{StatusCode: http.StatusNotFound}
	fsys := NewProjectionFileSystem(client)

	errc := fsys.Unlink("/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st")
	if errc != 0 {
		t.Fatalf("unlink errno: %v", errc)
	}
}

func TestRenameProjectedTonelFileUsesProjectionProtocol(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	fsys := NewProjectionFileSystem(client)

	errc := fsys.Rename(
		"/tonel/PharoImageFS/Old.class.st",
		"/tonel/PharoImageFS/New.class.st")
	if errc != 0 {
		t.Fatalf("rename errno: %v", errc)
	}

	if client.renamedPath != "/tonel/PharoImageFS/Old.class.st" {
		t.Fatalf("unexpected renamed path: %s", client.renamedPath)
	}
	if client.renameTarget != "/tonel/PharoImageFS/New.class.st" {
		t.Fatalf("unexpected rename target: %s", client.renameTarget)
	}
}

func TestPathLevelTruncateDefersProjectionWriteUntilHandleFlush(t *testing.T) {
	client := fakeProjectionClientForTonelPackage()
	client.readContents = []byte("original source")
	client.stats["/tonel/PharoImageFS/PharoImageFSProjectionHTTPServer.class.st"] = protocol.Entry{
		Name:     "PharoImageFSProjectionHTTPServer.class.st",
		Kind:     protocol.File,
		Writable: true,
	}
	fsys := NewProjectionFileSystem(client)

	if errc := fsys.Truncate("/tonel/PharoImageFS/PharoImageFSProjectionHTTPServer.class.st", 0, ^uint64(0)); errc != 0 {
		t.Fatalf("truncate errno: %v", errc)
	}
	if client.writtenPath != "" {
		t.Fatalf("path-level truncate should not write projection before final flush")
	}

	errc, handle := fsys.Open("/tonel/PharoImageFS/PharoImageFSProjectionHTTPServer.class.st", syscall.O_RDWR)
	if errc != 0 {
		t.Fatalf("open errno: %v", errc)
	}
	if written := fsys.Write("", []byte("replacement source"), 0, handle); written != len("replacement source") {
		t.Fatalf("unexpected write result: %v", written)
	}
	if errc := fsys.Flush("", handle); errc != 0 {
		t.Fatalf("flush errno: %v", errc)
	}

	if client.writtenPath != "/tonel/PharoImageFS/PharoImageFSProjectionHTTPServer.class.st" {
		t.Fatalf("unexpected written path: %s", client.writtenPath)
	}
	if string(client.writtenContents) != "replacement source" {
		t.Fatalf("unexpected written contents: %q", client.writtenContents)
	}
}

func TestProjectedTonelFilePathIgnoresAppleDoubleSidecars(t *testing.T) {
	if isProjectedTonelFilePath("/tonel/PharoImageFS/._PharoImageFSProjectionHTTPServer.class.st") {
		t.Fatalf("AppleDouble sidecar should not be treated as a projected Tonel file")
	}
}

func TestMountOptionsSuppressMacOSMetadataFiles(t *testing.T) {
	options := mountOptions(Config{})
	joinedOptions := strings.Join(options, " ")
	for _, expected := range []string{"-s", "noappledouble", "noapplexattr"} {
		if !strings.Contains(joinedOptions, expected) {
			t.Fatalf("missing %s in mount options %#v", expected, options)
		}
	}
}

func fakeProjectionClientForTonelPackage() *fakeClient {
	return &fakeClient{
		stats: map[string]protocol.Entry{
			"/tonel/PharoImageFS": {
				Name:     "PharoImageFS",
				Kind:     protocol.Directory,
				Writable: true,
			},
		},
	}
}

func contains(collection []string, element string) bool {
	for _, each := range collection {
		if each == element {
			return true
		}
	}
	return false
}
