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

func TestParseConfigAcceptsRepeatedMountOptions(t *testing.T) {
	config, err := ParseConfig([]string{
		"--mount-option",
		"backend=fskit",
		"--mount-option",
		"volname=Pharo Image",
		"/tmp/mount",
	})
	if err != nil {
		t.Fatal(err)
	}

	if len(config.MountOptions) != 2 {
		t.Fatalf("unexpected mount options: %#v", config.MountOptions)
	}
	if config.MountOptions[0] != "backend=fskit" {
		t.Fatalf("unexpected first mount option: %s", config.MountOptions[0])
	}
	if config.MountOptions[1] != "volname=Pharo Image" {
		t.Fatalf("unexpected second mount option: %s", config.MountOptions[1])
	}
}

func TestEnsureMountPointCreatesMissingDirectory(t *testing.T) {
	mountPoint := filepath.Join(t.TempDir(), "missing", "mount")
	if err := ensureMountPoint(mountPoint); err != nil {
		t.Fatal(err)
	}
}
