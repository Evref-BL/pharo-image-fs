package mount

import "fmt"

// Run starts the pharo-image-fs mount daemon.
//
// The first implementation target is macFUSE on macOS. The current scaffold
// intentionally does not bind to a FUSE library yet; the next step is to define
// the projection protocol and wire a read-only filesystem around it.
func Run(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: pharo-image-fs <mountpoint>")
	}

	return fmt.Errorf("mount daemon is not implemented yet")
}
