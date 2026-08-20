package mount

import (
	"context"
	"hash/fnv"
	"io"
	"io/fs"
	"os"
	"path"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
	billy "github.com/go-git/go-billy/v5"
)

// PharoFS implements billy.Filesystem backed by a Pharo projection protocol client.
// The overlay provides write persistence across NFS stateless RPCs.
type PharoFS struct {
	client  protocol.Client
	overlay *Overlay
}

// NewPharoFS creates a PharoFS backed by the given projection client.
func NewPharoFS(client protocol.Client) *PharoFS {
	return &PharoFS{
		client:  client,
		overlay: NewOverlay(),
	}
}

// Create creates a new empty file in the overlay.
func (fsys *PharoFS) Create(filename string) (billy.File, error) {
	fsys.overlay.Create(filename, nil)
	return &pharoFile{
		path:     filename,
		contents: []byte{},
		dirty:    false,
		fsys:     fsys,
	}, nil
}

// Open opens a file for reading.
func (fsys *PharoFS) Open(filename string) (billy.File, error) {
	return fsys.OpenFile(filename, os.O_RDONLY, 0)
}

// OpenFile opens a file with the given flags and permissions.
func (fsys *PharoFS) OpenFile(filename string, flag int, perm os.FileMode) (billy.File, error) {
	isCreate := flag&os.O_CREATE != 0
	isTruncate := flag&os.O_TRUNC != 0
	isExist := flag&os.O_EXCL != 0

	if isCreate {
		if isExist {
			// Check if file exists in overlay or Pharo
			if _, ok := fsys.overlay.Stat(filename); ok {
				return nil, os.ErrExist
			}
			ctx := context.Background()
			if _, err := fsys.client.Stat(ctx, filename); err == nil {
				return nil, os.ErrExist
			}
			// File doesn't exist, create it
			fsys.overlay.Create(filename, nil)
			return &pharoFile{
				path:     filename,
				contents: []byte{},
				dirty:    false,
				fsys:     fsys,
			}, nil
		}
		// Open with O_CREATE but not O_EXCL - create if doesn't exist
		if _, ok := fsys.overlay.Stat(filename); !ok {
			ctx := context.Background()
			if _, err := fsys.client.Stat(ctx, filename); err != nil {
				fsys.overlay.Create(filename, nil)
				return &pharoFile{
					path:     filename,
					contents: []byte{},
					dirty:    false,
					fsys:     fsys,
				}, nil
			}
		}
	}

	// Read contents - overlay is source of truth for files being written
	var contents []byte
	if data, ok := fsys.overlay.Read(filename); ok {
		contents = data
	} else {
		ctx := context.Background()
		data, err := fsys.client.Read(ctx, filename)
		if err != nil {
			return nil, err
		}
		contents = data
	}

	if isTruncate {
		contents = []byte{}
	}

	return &pharoFile{
		path:     filename,
		contents: contents,
		dirty:    false,
		fsys:     fsys,
	}, nil
}

// Stat returns a FileInfo describing the named file.
func (fsys *PharoFS) Stat(filename string) (fs.FileInfo, error) {
	// Check overlay first
	if entry, ok := fsys.overlay.Stat(filename); ok {
		return &pharoFileInfo{
			entry: entry,
			path:  filename,
		}, nil
	}

	ctx := context.Background()
	entry, err := fsys.client.Stat(ctx, filename)
	if err != nil {
		return nil, err
	}
	return &pharoFileInfo{
		entry: entry,
		path:  filename,
	}, nil
}

// Rename renames oldpath to newpath.
func (fsys *PharoFS) Rename(oldpath, newpath string) error {
	// Check if source is in overlay
	if _, ok := fsys.overlay.Stat(oldpath); ok {
		fsys.overlay.Move(oldpath, newpath)
		return nil
	}
	ctx := context.Background()
	return fsys.client.Rename(ctx, oldpath, newpath)
}

// Remove removes the named file.
func (fsys *PharoFS) Remove(filename string) error {
	// Remove from overlay if present
	if fsys.overlay.Delete(filename) {
		return nil
	}
	ctx := context.Background()
	return fsys.client.Delete(ctx, filename)
}

// Join joins path elements into a single path, always returning an
// absolute path with a leading slash.  The NFS server hands the result
// to billy methods, and the Pharo projection backend expects paths like
// "/tonel/Foo.class.st".
func (fsys *PharoFS) Join(elem ...string) string {
	p := path.Join(elem...)
	if p == "" {
		return "/"
	}
	if p[0] != '/' {
		p = "/" + p
	}
	return p
}

// ReadDir reads the directory named path and returns a list of fs.FileInfo.
func (fsys *PharoFS) ReadDir(dirPath string) ([]fs.FileInfo, error) {
	ctx := context.Background()
	entries, err := fsys.client.List(ctx, dirPath)
	if err != nil {
		return nil, err
	}

	// Merge overlay entries
	entries = mergeEntries(entries, fsys.overlay.EntriesIn(dirPath))

	infos := make([]fs.FileInfo, len(entries))
	for i, entry := range entries {
		infos[i] = &pharoFileInfo{
			entry: entry,
			path:  dirPath + "/" + entry.Name,
		}
	}

	sort.Slice(infos, func(i, j int) bool {
		return infos[i].Name() < infos[j].Name()
	})

	return infos, nil
}

// MkdirAll is a no-op for Pharo projections (directories are managed by the image).
func (fsys *PharoFS) MkdirAll(dirPath string, perm os.FileMode) error {
	return nil
}

// TempFile creates a temporary file.
func (fsys *PharoFS) TempFile(dir, prefix string) (billy.File, error) {
	name := path.Join(dir, prefix+"-"+time.Now().Format("20060102150405.000000000"))
	fsys.overlay.Create(name, nil)
	return &pharoFile{
		path:     name,
		contents: []byte{},
		dirty:    false,
		fsys:     fsys,
	}, nil
}

// Lstat returns a FileInfo describing the named file.
func (fsys *PharoFS) Lstat(filename string) (fs.FileInfo, error) {
	return fsys.Stat(filename)
}

// Symlink is not supported in the Pharo projection.
func (fsys *PharoFS) Symlink(target, link string) error {
	return &os.PathError{Op: "symlink", Path: link, Err: os.ErrInvalid}
}

// Readlink is not supported in the Pharo projection.
func (fsys *PharoFS) Readlink(link string) (string, error) {
	return "", &os.PathError{Op: "readlink", Path: link, Err: os.ErrInvalid}
}

// Chroot returns a new PharoFS rooted at the given path.
func (fsys *PharoFS) Chroot(dirPath string) (billy.Filesystem, error) {
	return &pharoChrootFS{
		PharoFS: fsys,
		root:    dirPath,
	}, nil
}

// Root returns the root path of this filesystem.
func (fsys *PharoFS) Root() string {
	return "/"
}

// pharoFile implements billy.File backed by a Pharo projection.
// It buffers writes in memory and flushes to the overlay on Close.
type pharoFile struct {
	path     string
	contents []byte
	offset   int64
	dirty    bool
	closed   bool
	fsys     *PharoFS
	mu       sync.Mutex
}

var _ billy.File = (*pharoFile)(nil)

func (f *pharoFile) Name() string {
	return f.path
}

func (f *pharoFile) Read(p []byte) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return 0, os.ErrClosed
	}
	if f.offset >= int64(len(f.contents)) {
		return 0, nil // EOF for NFS reads past end
	}
	n := copy(p, f.contents[f.offset:])
	f.offset += int64(n)
	if f.offset >= int64(len(f.contents)) {
		return n, nil // Return nil error at EOF boundary
	}
	return n, nil
}

func (f *pharoFile) ReadAt(p []byte, off int64) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return 0, os.ErrClosed
	}
	if off >= int64(len(f.contents)) {
		return 0, nil // EOF
	}
	n := copy(p, f.contents[off:])
	if n < len(p) {
		return n, nil // EOF
	}
	return n, nil
}

func (f *pharoFile) Write(p []byte) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return 0, os.ErrClosed
	}
	f.dirty = true
	end := f.offset + int64(len(p))
	if end > int64(len(f.contents)) {
		grown := make([]byte, end)
		copy(grown, f.contents)
		f.contents = grown
	}
	copy(f.contents[f.offset:], p)
	f.offset = end
	return len(p), nil
}

func (f *pharoFile) WriteAt(p []byte, off int64) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return 0, os.ErrClosed
	}
	f.dirty = true
	end := off + int64(len(p))
	if end > int64(len(f.contents)) {
		grown := make([]byte, end)
		copy(grown, f.contents)
		f.contents = grown
	}
	copy(f.contents[off:], p)
	return len(p), nil
}

func (f *pharoFile) Seek(offset int64, whence int) (int64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return 0, os.ErrClosed
	}
	var newOffset int64
	switch whence {
	case io.SeekStart:
		newOffset = offset
	case io.SeekCurrent:
		newOffset = f.offset + offset
	case io.SeekEnd:
		newOffset = int64(len(f.contents)) + offset
	default:
		return 0, os.ErrInvalid
	}
	if newOffset < 0 {
		return 0, os.ErrInvalid
	}
	f.offset = newOffset
	return newOffset, nil
}

func (f *pharoFile) Truncate(size int64) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return os.ErrClosed
	}
	f.dirty = true
	if size < int64(len(f.contents)) {
		f.contents = f.contents[:size]
	} else if size > int64(len(f.contents)) {
		grown := make([]byte, size)
		copy(grown, f.contents)
		f.contents = grown
	}
	return nil
}

func (f *pharoFile) Close() error {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return os.ErrClosed
	}
	f.closed = true

	// Flush dirty content to overlay
	if f.dirty && f.fsys != nil {
		f.fsys.overlay.Create(f.path, f.contents)
		// Write through to Pharo for Tonel files
		if isProjectedTonelFilePath(f.path) {
			ctx := context.Background()
			if _, err := f.fsys.client.Write(ctx, f.path, f.contents); err != nil {
				return err
			}
			f.fsys.overlay.Delete(f.path)
		}
	}
	return nil
}

func (f *pharoFile) Lock() error   { return nil }
func (f *pharoFile) Unlock() error { return nil }

// pharoFileInfo implements fs.FileInfo for a projected entry.
type pharoFileInfo struct {
	entry protocol.Entry
	path  string
}

func (fi *pharoFileInfo) Name() string {
	return path.Base(fi.path)
}

func (fi *pharoFileInfo) Size() int64 {
	return int64(fi.entry.Size)
}

func (fi *pharoFileInfo) Mode() fs.FileMode {
	if fi.entry.Kind == protocol.Directory {
		return fs.ModeDir | 0o755
	}
	return 0o644
}

func (fi *pharoFileInfo) ModTime() time.Time {
	// Return a deterministic time derived from the path so the NFS
	// SETATTR guard (ctime comparison) doesn't reject every write.
	h := fnv.New32a()
	h.Write([]byte(fi.path))
	return time.Unix(int64(h.Sum32()%1_000_000_000), 0)
}

func (fi *pharoFileInfo) IsDir() bool {
	return fi.entry.Kind == protocol.Directory
}

func (fi *pharoFileInfo) Sys() any {
	return nil
}

// pharoChrootFS is a PharoFS rooted at a subpath.
type pharoChrootFS struct {
	*PharoFS
	root string
}

func (fsys *pharoChrootFS) Chroot(dirPath string) (billy.Filesystem, error) {
	return &pharoChrootFS{
		PharoFS: fsys.PharoFS,
		root:    fsys.root + "/" + dirPath,
	}, nil
}

func (fsys *pharoChrootFS) Root() string {
	return fsys.root
}

func (fsys *pharoChrootFS) Join(elem ...string) string {
	return fsys.PharoFS.Join(elem...)
}

func (fsys *pharoChrootFS) resolve(filename string) string {
	if strings.HasPrefix(filename, "/") {
		return filename
	}
	return fsys.root + "/" + filename
}

func (fsys *pharoChrootFS) Create(filename string) (billy.File, error) {
	return fsys.PharoFS.Create(fsys.resolve(filename))
}

func (fsys *pharoChrootFS) Open(filename string) (billy.File, error) {
	return fsys.PharoFS.Open(fsys.resolve(filename))
}

func (fsys *pharoChrootFS) OpenFile(filename string, flag int, perm os.FileMode) (billy.File, error) {
	return fsys.PharoFS.OpenFile(fsys.resolve(filename), flag, perm)
}

func (fsys *pharoChrootFS) Stat(filename string) (fs.FileInfo, error) {
	return fsys.PharoFS.Stat(fsys.resolve(filename))
}

func (fsys *pharoChrootFS) Rename(oldpath, newpath string) error {
	return fsys.PharoFS.Rename(fsys.resolve(oldpath), fsys.resolve(newpath))
}

func (fsys *pharoChrootFS) Remove(filename string) error {
	return fsys.PharoFS.Remove(fsys.resolve(filename))
}

func (fsys *pharoChrootFS) ReadDir(dirPath string) ([]fs.FileInfo, error) {
	return fsys.PharoFS.ReadDir(fsys.resolve(dirPath))
}

func (fsys *pharoChrootFS) Lstat(filename string) (fs.FileInfo, error) {
	return fsys.PharoFS.Stat(fsys.resolve(filename))
}

// Ensure interface compliance
var _ billy.Filesystem = (*PharoFS)(nil)
var _ billy.Filesystem = (*pharoChrootFS)(nil)
var _ billy.Change = (*PharoFS)(nil)

// Chmod is a no-op; the Pharo projection manages permissions.
func (fsys *PharoFS) Chmod(name string, mode os.FileMode) error { return nil }

// Lchown is a no-op; the Pharo projection manages ownership.
func (fsys *PharoFS) Lchown(name string, uid, gid int) error { return nil }

// Chown is a no-op; the Pharo projection manages ownership.
func (fsys *PharoFS) Chown(name string, uid, gid int) error { return nil }

// Chtimes is a no-op; the Pharo projection ignores access/modification times.
func (fsys *PharoFS) Chtimes(name string, atime, mtime time.Time) error { return nil }

func mergeEntries(projected []protocol.Entry, overlay []protocol.Entry) []protocol.Entry {
	byName := map[string]protocol.Entry{}
	for _, entry := range projected {
		byName[entry.Name] = entry
	}

	merged := make([]protocol.Entry, 0, len(projected)+len(overlay))
	merged = append(merged, projected...)
	overlayOnly := make([]protocol.Entry, 0, len(overlay))
	for _, entry := range overlay {
		if _, exists := byName[entry.Name]; exists {
			continue
		}
		overlayOnly = append(overlayOnly, entry)
	}
	sort.Slice(overlayOnly, func(i int, j int) bool {
		return overlayOnly[i].Name < overlayOnly[j].Name
	})
	for _, entry := range overlayOnly {
		merged = append(merged, entry)
	}

	return merged
}

func isProjectedTonelFilePath(projectionPath string) bool {
	base := path.Base(projectionPath)
	return strings.HasPrefix(projectionPath, "/tonel/") &&
		!strings.HasPrefix(base, "._") &&
		(strings.HasSuffix(base, ".class.st") ||
			strings.HasSuffix(base, ".extension.st"))
}
