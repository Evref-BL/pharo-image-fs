package mount

import (
	"fmt"
	"os"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
)

// Run starts the pharo-image-fs mount daemon using NFS.
func Run(args []string) error {
	return RunNFS(args)
}

// Mount mounts the Pharo projection filesystem at mountPoint using NFS.
func Mount(mountPoint string, client protocol.Client, config Config) (*NFSServer, error) {
	return MountNFS(mountPoint, client, config)
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
