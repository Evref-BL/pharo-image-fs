package mount

import (
	"path/filepath"
	"testing"
)

func TestParseConfigUsesDefaultEndpoint(t *testing.T) {
	config, err := ParseConfig([]string{"/tmp/pharo-image-fs"})
	if err != nil {
		t.Fatal(err)
	}

	if config.Endpoint != "http://127.0.0.1:9013/projection" {
		t.Fatalf("unexpected endpoint: %s", config.Endpoint)
	}
	if config.MountPoint != "/tmp/pharo-image-fs" {
		t.Fatalf("unexpected mount point: %s", config.MountPoint)
	}
}

func TestParseConfigAcceptsEndpoint(t *testing.T) {
	config, err := ParseConfig([]string{"--endpoint", "http://127.0.0.1:9100/projection", "/tmp/mount"})
	if err != nil {
		t.Fatal(err)
	}

	if config.Endpoint != "http://127.0.0.1:9100/projection" {
		t.Fatalf("unexpected endpoint: %s", config.Endpoint)
	}
}

func TestEnsureMountPointCreatesMissingDirectory(t *testing.T) {
	mountPoint := filepath.Join(t.TempDir(), "missing", "mount")
	if err := ensureMountPoint(mountPoint); err != nil {
		t.Fatal(err)
	}
}
