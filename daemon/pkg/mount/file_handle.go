package mount

import (
	"context"
	"sync"
	"syscall"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
)

// FileHandle buffers one opened projected file.
type FileHandle struct {
	mu       sync.Mutex
	client   protocol.Client
	path     string
	contents []byte
	writable bool
	dirty    bool
	flush    func(context.Context, string, []byte) error
}

func (h *FileHandle) Read(dest []byte, off int64) (int, syscall.Errno) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if off < 0 {
		return 0, syscall.EINVAL
	}
	if off >= int64(len(h.contents)) {
		return 0, 0
	}

	start := int(off)
	end := min(start+len(dest), len(h.contents))
	return copy(dest, h.contents[start:end]), 0
}

func (h *FileHandle) Write(data []byte, off int64) (int, syscall.Errno) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.writable {
		return 0, syscall.EROFS
	}
	if off < 0 {
		return 0, syscall.EINVAL
	}

	h.growTo(int(off) + len(data))
	copy(h.contents[off:], data)
	h.dirty = true
	return len(data), 0
}

func (h *FileHandle) Flush(ctx context.Context) syscall.Errno {
	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.dirty {
		return 0
	}

	err := h.flushContents(ctx)
	if err != nil {
		return errnoFor(err)
	}
	h.dirty = false
	return 0
}

func (h *FileHandle) Truncate(size int64) syscall.Errno {
	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.writable {
		return syscall.EROFS
	}
	if size < 0 {
		return syscall.EINVAL
	}

	h.resizeTo(int(size))
	h.dirty = true
	return 0
}

func (h *FileHandle) flushContents(ctx context.Context) error {
	if h.flush != nil {
		return h.flush(ctx, h.path, h.contents)
	}

	_, err := h.client.Write(ctx, h.path, h.contents)
	return err
}

func (h *FileHandle) growTo(size int) {
	if len(h.contents) >= size {
		return
	}

	grown := make([]byte, size)
	copy(grown, h.contents)
	h.contents = grown
}

func (h *FileHandle) resizeTo(size int) {
	if len(h.contents) == size {
		return
	}
	if len(h.contents) > size {
		h.contents = h.contents[:size]
		return
	}

	h.growTo(size)
}
