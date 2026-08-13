package mount

import (
	"context"
	"path"
	"sort"
	"sync"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
)

// Overlay stores files created by editors as part of safe-save workflows before
// they are committed to the projection by rename.
type Overlay struct {
	mu    sync.Mutex
	files map[string][]byte
}

func NewOverlay() *Overlay {
	return &Overlay{
		files: map[string][]byte{},
	}
}

func (o *Overlay) Create(projectionPath string, contents []byte) {
	o.mu.Lock()
	defer o.mu.Unlock()

	o.files[projectionPath] = append([]byte(nil), contents...)
}

func (o *Overlay) Read(projectionPath string) ([]byte, bool) {
	o.mu.Lock()
	defer o.mu.Unlock()

	contents, ok := o.files[projectionPath]
	if !ok {
		return nil, false
	}

	return append([]byte(nil), contents...), true
}

func (o *Overlay) Write(_ context.Context, projectionPath string, contents []byte) error {
	o.mu.Lock()
	defer o.mu.Unlock()

	o.files[projectionPath] = append([]byte(nil), contents...)
	return nil
}

func (o *Overlay) Delete(projectionPath string) bool {
	o.mu.Lock()
	defer o.mu.Unlock()

	if _, ok := o.files[projectionPath]; !ok {
		return false
	}

	delete(o.files, projectionPath)
	return true
}

func (o *Overlay) Move(oldPath string, newPath string) bool {
	o.mu.Lock()
	defer o.mu.Unlock()

	contents, ok := o.files[oldPath]
	if !ok {
		return false
	}

	o.files[newPath] = contents
	delete(o.files, oldPath)
	return true
}

func (o *Overlay) Stat(projectionPath string) (protocol.Entry, bool) {
	o.mu.Lock()
	defer o.mu.Unlock()

	contents, ok := o.files[projectionPath]
	if !ok {
		return protocol.Entry{}, false
	}

	return protocol.Entry{
		Name:     path.Base(projectionPath),
		Kind:     protocol.File,
		Size:     uint64(len(contents)),
		Writable: true,
	}, true
}

func (o *Overlay) EntriesIn(parentPath string) []protocol.Entry {
	o.mu.Lock()
	defer o.mu.Unlock()

	entries := make([]protocol.Entry, 0)
	for projectionPath, contents := range o.files {
		if path.Dir(projectionPath) != parentPath {
			continue
		}

		entries = append(entries, protocol.Entry{
			Name:     path.Base(projectionPath),
			Kind:     protocol.File,
			Size:     uint64(len(contents)),
			Writable: true,
		})
	}

	sort.Slice(entries, func(i int, j int) bool {
		return entries[i].Name < entries[j].Name
	})
	return entries
}
