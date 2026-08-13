package mount

import (
	"context"
	"errors"
	"syscall"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
)

func errnoFor(err error) syscall.Errno {
	switch {
	case err == nil:
		return 0
	case protocol.NotFound(err):
		return syscall.ENOENT
	case protocol.ReadOnly(err):
		return syscall.EROFS
	case errors.Is(err, context.Canceled):
		return syscall.EINTR
	default:
		return syscall.EIO
	}
}
