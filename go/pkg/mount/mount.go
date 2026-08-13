package mount

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
)

// Run starts the pharo-image-fs mount daemon.
func Run(args []string) error {
	config, err := ParseConfig(args)
	if err != nil {
		return err
	}

	client, err := protocol.NewHTTPClient(config.Endpoint)
	if err != nil {
		return err
	}

	server, err := Mount(config.MountPoint, client, config)
	if err != nil {
		return err
	}
	server.Wait()
	return nil
}

// Mount mounts the Pharo projection filesystem at mountPoint.
func Mount(mountPoint string, client protocol.Client, config Config) (*fuse.Server, error) {
	if err := ensureMountPoint(mountPoint); err != nil {
		return nil, err
	}

	timeout := time.Second
	options := &fs.Options{
		AttrTimeout:     &timeout,
		EntryTimeout:    &timeout,
		NegativeTimeout: &timeout,
		MountOptions: fuse.MountOptions{
			Name:  "pharo-image-fs",
			Debug: config.Debug,
		},
	}

	root := NewRoot(client)
	root.logger = log.New(os.Stderr, "pharo-image-fs: ", log.LstdFlags)
	return fs.Mount(mountPoint, root, options)
}

func ensureMountPoint(mountPoint string) error {
	info, err := os.Stat(mountPoint)
	if err != nil {
		if os.IsNotExist(err) {
			return os.MkdirAll(mountPoint, 0o755)
		}
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("mountpoint is not a directory: %s", mountPoint)
	}

	return nil
}
