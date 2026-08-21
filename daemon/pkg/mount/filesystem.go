package mount

import (
	"context"
	"fmt"
	"log"
	"os"
	"path"
	"runtime"
	"sort"
	"strings"
	"sync"
	"syscall"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
	"github.com/winfsp/cgofuse/fuse"
)

// ProjectionFileSystem adapts Pharo projection protocol operations to FUSE.
type ProjectionFileSystem struct {
	fuse.FileSystemBase

	client  protocol.Client
	overlay *Overlay
	logger  projectionLogger

	mu         sync.Mutex
	nextHandle uint64
	handles    map[uint64]*FileHandle
	mounted    bool
}

type projectionLogger interface {
	Printf(format string, args ...any)
}

func NewProjectionFileSystem(client protocol.Client) *ProjectionFileSystem {
	return &ProjectionFileSystem{
		client:     client,
		overlay:    NewOverlay(),
		handles:    map[uint64]*FileHandle{},
		nextHandle: 1,
	}
}

func (fsys *ProjectionFileSystem) Init() {
	fsys.mu.Lock()
	defer fsys.mu.Unlock()

	fsys.mounted = true
}

func (fsys *ProjectionFileSystem) Getattr(projectionPath string, stat *fuse.Stat_t, _ uint64) int {
	entry, errno := fsys.entryForPath(projectionPath)
	if errno != 0 {
		return -int(errno)
	}

	fillStat(stat, projectionPath, entry)
	return 0
}

func (fsys *ProjectionFileSystem) Readdir(projectionPath string, fill func(name string, stat *fuse.Stat_t, ofst int64) bool, _ int64, _ uint64) int {
	entry, errno := fsys.entryForPath(projectionPath)
	if errno != 0 {
		return -int(errno)
	}
	if entry.Kind != protocol.Directory {
		return -int(syscall.ENOTDIR)
	}

	entries, err := fsys.client.List(context.Background(), projectionPath)
	if err != nil {
		return -int(errnoFor(err))
	}

	fill(".", nil, 0)
	fill("..", nil, 0)
	for _, childEntry := range mergeEntries(entries, fsys.overlay.EntriesIn(projectionPath)) {
		stat := fuse.Stat_t{}
		childPath := joinProjectionPath(projectionPath, childEntry.Name)
		childEntry = writableEntryForPath(childPath, childEntry)
		fillStat(&stat, childPath, childEntry)
		if !fill(childEntry.Name, &stat, 0) {
			break
		}
	}
	return 0
}

func (fsys *ProjectionFileSystem) Open(projectionPath string, flags int) (int, uint64) {
	entry, errno := fsys.entryForPath(projectionPath)
	if errno != 0 {
		return -int(errno), ^uint64(0)
	}
	if entry.Kind == protocol.Directory {
		return -int(syscall.EISDIR), ^uint64(0)
	}

	writable := openFlagsAreWritable(flags)
	if writable && !entry.Writable {
		return -int(syscall.EROFS), ^uint64(0)
	}

	contents := []byte{}
	if !openFlagsTruncate(flags) {
		if overlayContents, ok := fsys.overlay.Read(projectionPath); ok {
			contents = overlayContents
		} else {
			readContents, err := fsys.client.Read(context.Background(), projectionPath)
			if err != nil {
				return -int(errnoFor(err)), ^uint64(0)
			}
			contents = readContents
		}
	}

	handle := &FileHandle{
		client:   fsys.client,
		path:     projectionPath,
		contents: contents,
		writable: writable,
		dirty:    openFlagsTruncate(flags),
		flush:    fsys.writeProjection,
	}
	return 0, fsys.registerHandle(handle)
}

func (fsys *ProjectionFileSystem) Create(projectionPath string, flags int, _ uint32) (int, uint64) {
	if !isWritableProjectionPath(projectionPath) {
		return -int(syscall.EROFS), ^uint64(0)
	}

	parentPath := path.Dir(projectionPath)
	parentEntry, errno := fsys.entryForPath(parentPath)
	if errno != 0 {
		return -int(errno), ^uint64(0)
	}
	if parentEntry.Kind != protocol.Directory {
		return -int(syscall.ENOTDIR), ^uint64(0)
	}

	if _, ok := fsys.overlay.Stat(projectionPath); ok {
		return -int(syscall.EEXIST), ^uint64(0)
	}
	if _, err := fsys.client.Stat(context.Background(), projectionPath); err == nil {
		return -int(syscall.EEXIST), ^uint64(0)
	} else if !protocol.NotFound(err) {
		return -int(errnoFor(err)), ^uint64(0)
	}

	fsys.overlay.Create(projectionPath, nil)
	flush := fsys.overlay.Write
	if isProjectedTonelFilePath(projectionPath) {
		flush = func(ctx context.Context, projectionPath string, contents []byte) error {
			if err := fsys.writeProjection(ctx, projectionPath, contents); err != nil {
				return err
			}
			fsys.overlay.Delete(projectionPath)
			return nil
		}
	}

	handle := &FileHandle{
		path:     projectionPath,
		contents: []byte{},
		writable: openFlagsAreWritable(flags),
		flush:    flush,
	}
	return 0, fsys.registerHandle(handle)
}

func (fsys *ProjectionFileSystem) Read(_ string, buff []byte, ofst int64, fh uint64) int {
	handle, ok := fsys.handle(fh)
	if !ok {
		return -int(syscall.EBADF)
	}

	read, errno := handle.Read(buff, ofst)
	if errno != 0 {
		return -int(errno)
	}
	return read
}

func (fsys *ProjectionFileSystem) Write(_ string, buff []byte, ofst int64, fh uint64) int {
	handle, ok := fsys.handle(fh)
	if !ok {
		return -int(syscall.EBADF)
	}

	written, errno := handle.Write(buff, ofst)
	if errno != 0 {
		return -int(errno)
	}
	return written
}

func (fsys *ProjectionFileSystem) Flush(_ string, fh uint64) int {
	handle, ok := fsys.handle(fh)
	if !ok {
		return -int(syscall.EBADF)
	}

	if errno := handle.Flush(context.Background()); errno != 0 {
		return -int(errno)
	}
	return 0
}

func (fsys *ProjectionFileSystem) Release(_ string, fh uint64) int {
	fsys.mu.Lock()
	defer fsys.mu.Unlock()

	delete(fsys.handles, fh)
	return 0
}

func (fsys *ProjectionFileSystem) Truncate(projectionPath string, size int64, fh uint64) int {
	if handle, ok := fsys.handle(fh); ok {
		if errno := handle.Truncate(size); errno != 0 {
			return -int(errno)
		}
		return 0
	}

	if handles := fsys.handlesForPath(projectionPath); len(handles) > 0 {
		for _, handle := range handles {
			if errno := handle.Truncate(size); errno != 0 {
				return -int(errno)
			}
		}
		return 0
	}

	if size < 0 {
		return -int(syscall.EINVAL)
	}
	if !isWritableProjectionPath(projectionPath) {
		return -int(syscall.EROFS)
	}

	contents, err := fsys.contentsForPath(projectionPath)
	if err != nil {
		return -int(errnoFor(err))
	}
	contents = resizedContents(contents, int(size))
	_ = fsys.overlay.Write(context.Background(), projectionPath, contents)
	return 0
}

func (fsys *ProjectionFileSystem) Access(projectionPath string, mask uint32) int {
	entry, errno := fsys.entryForPath(projectionPath)
	if errno != 0 {
		return -int(errno)
	}
	if mask&2 != 0 && !entry.Writable {
		return -int(syscall.EROFS)
	}
	return 0
}

func (fsys *ProjectionFileSystem) Unlink(projectionPath string) int {
	if fsys.overlay.Delete(projectionPath) {
		return 0
	}
	if !isWritableProjectionPath(projectionPath) {
		return -int(syscall.EROFS)
	}
	if err := fsys.client.Delete(context.Background(), projectionPath); err != nil {
		if protocol.NotFound(err) {
			return 0
		}
		fsys.logf("delete %s failed: %v", projectionPath, err)
		return -int(errnoFor(err))
	}
	return 0
}

func (fsys *ProjectionFileSystem) Rename(oldPath string, newPath string) int {
	contents, ok := fsys.overlay.Read(oldPath)
	if ok && isProjectedTonelFilePath(newPath) {
		if err := fsys.writeProjection(context.Background(), newPath, contents); err != nil {
			return -int(errnoFor(err))
		}
		fsys.overlay.Delete(oldPath)
		fsys.overlay.Delete(newPath)
		return 0
	}

	if ok {
		if !isWritableProjectionPath(newPath) {
			return -int(syscall.EROFS)
		}

		fsys.overlay.Move(oldPath, newPath)
		return 0
	}

	if !isWritableProjectionPath(oldPath) || !isWritableProjectionPath(newPath) {
		return -int(syscall.EROFS)
	}
	if err := fsys.client.Rename(context.Background(), oldPath, newPath); err != nil {
		fsys.logf("rename %s to %s failed: %v", oldPath, newPath, err)
		return -int(errnoFor(err))
	}
	return 0
}

func (fsys *ProjectionFileSystem) entryForPath(projectionPath string) (protocol.Entry, syscall.Errno) {
	if projectionPath == "/" {
		return protocol.Entry{Name: "/", Kind: protocol.Directory}, 0
	}
	if overlayEntry, ok := fsys.overlay.Stat(projectionPath); ok {
		return writableEntryForPath(projectionPath, overlayEntry), 0
	}

	entry, err := fsys.client.Stat(context.Background(), projectionPath)
	if err != nil {
		return protocol.Entry{}, errnoFor(err)
	}
	return writableEntryForPath(projectionPath, entry), 0
}

func (fsys *ProjectionFileSystem) registerHandle(handle *FileHandle) uint64 {
	fsys.mu.Lock()
	defer fsys.mu.Unlock()

	fh := fsys.nextHandle
	fsys.nextHandle++
	fsys.handles[fh] = handle
	return fh
}

func (fsys *ProjectionFileSystem) handle(fh uint64) (*FileHandle, bool) {
	fsys.mu.Lock()
	defer fsys.mu.Unlock()

	handle, ok := fsys.handles[fh]
	return handle, ok
}

func (fsys *ProjectionFileSystem) handlesForPath(projectionPath string) []*FileHandle {
	fsys.mu.Lock()
	defer fsys.mu.Unlock()

	handles := make([]*FileHandle, 0)
	for _, handle := range fsys.handles {
		if handle.path == projectionPath {
			handles = append(handles, handle)
		}
	}
	return handles
}

func (fsys *ProjectionFileSystem) contentsForPath(projectionPath string) ([]byte, error) {
	if overlayContents, ok := fsys.overlay.Read(projectionPath); ok {
		return overlayContents, nil
	}

	return fsys.client.Read(context.Background(), projectionPath)
}

func resizedContents(contents []byte, size int) []byte {
	if len(contents) == size {
		return contents
	}
	if len(contents) > size {
		return contents[:size]
	}

	resized := make([]byte, size)
	copy(resized, contents)
	return resized
}

func (fsys *ProjectionFileSystem) writeProjection(ctx context.Context, projectionPath string, contents []byte) error {
	result, err := fsys.client.Write(ctx, projectionPath, contents)
	if err != nil {
		fsys.logf("write %s failed: %v", projectionPath, err)
		return err
	}

	fsys.logDiagnostics(projectionPath, result.Diagnostics)
	return nil
}

func (fsys *ProjectionFileSystem) logDiagnostics(projectionPath string, diagnostics []protocol.Diagnostic) {
	if len(diagnostics) == 0 {
		return
	}

	fsys.logf("write %s returned %d diagnostic(s)", projectionPath, len(diagnostics))
	for _, diagnostic := range diagnostics {
		fsys.logf("diagnostic %s: %s", diagnostic.Rule, diagnosticLineFor(diagnostic))
	}
}

func (fsys *ProjectionFileSystem) logf(format string, args ...any) {
	if fsys.logger == nil {
		return
	}

	fsys.logger.Printf(format, args...)
}

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

	return Mount(config.MountPoint, client, config)
}

// Mount mounts the Pharo projection filesystem at mountPoint.
func Mount(mountPoint string, client protocol.Client, config Config) error {
	if err := ensureMountPoint(mountPoint); err != nil {
		return err
	}
	if err := ensureFuseAvailable(); err != nil {
		return err
	}

	fsys := NewProjectionFileSystem(client)
	fsys.logger = log.New(os.Stderr, "pharo-image-fs: ", log.LstdFlags)
	host := fuse.NewFileSystemHost(fsys)
	options := mountOptions(config)
	if !host.Mount(mountPoint, options) {
		if fsys.wasMounted() {
			return nil
		}
		return fmt.Errorf("mount failed")
	}
	return nil
}

func ensureFuseAvailable() error {
	if runtime.GOOS != "darwin" {
		return nil
	}
	if _, err := os.Stat("/usr/local/lib/libfuse-t.dylib"); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}

	return fmt.Errorf("fuse-t is required on macOS: /usr/local/lib/libfuse-t.dylib was not found")
}

func (fsys *ProjectionFileSystem) wasMounted() bool {
	fsys.mu.Lock()
	defer fsys.mu.Unlock()

	return fsys.mounted
}

func mountOptions(config Config) []string {
	return append([]string{
		"-s",
		"-o", "volname=pharo-image-fs",
		"-o", "noappledouble",
		"-o", "noapplexattr",
	}, fuseOptions(config)...)
}

func fuseOptions(config Config) []string {
	options := make([]string, 0, len(config.MountOptions)*2+1)
	for _, option := range config.MountOptions {
		options = append(options, "-o", option)
	}
	if config.Debug {
		options = append(options, "-d")
	}
	return options
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

func fillStat(stat *fuse.Stat_t, projectionPath string, entry protocol.Entry) {
	stat.Mode = modeForEntry(entry)
	stat.Size = int64(entry.Size)
	stat.Ino = stableInodeFor(projectionPath)
	if entry.Kind == protocol.Directory {
		stat.Nlink = 2
		return
	}

	stat.Nlink = 1
}

func writableEntryForPath(projectionPath string, entry protocol.Entry) protocol.Entry {
	if entry.Kind == protocol.Directory && isWritableProjectionPath(projectionPath) {
		entry.Writable = true
	}

	return entry
}

func stableInodeFor(projectionPath string) uint64 {
	var hash uint64 = 14695981039346656037
	for _, b := range []byte(projectionPath) {
		hash ^= uint64(b)
		hash *= 1099511628211
	}
	return hash
}

func modeForEntry(entry protocol.Entry) uint32 {
	return modeForKind(entry.Kind, entry.Writable)
}

func modeForKind(kind protocol.EntryKind, writable bool) uint32 {
	switch kind {
	case protocol.Directory:
		if writable {
			return syscall.S_IFDIR | 0o755
		}
		return syscall.S_IFDIR | 0o555
	default:
		if writable {
			return syscall.S_IFREG | 0o644
		}
		return syscall.S_IFREG | 0o444
	}
}

func openFlagsAreWritable(flags int) bool {
	accessMode := flags & syscall.O_ACCMODE
	return accessMode == syscall.O_WRONLY || accessMode == syscall.O_RDWR
}

func openFlagsTruncate(flags int) bool {
	return flags&syscall.O_TRUNC != 0
}

func joinProjectionPath(parentPath string, name string) string {
	if parentPath == "/" {
		return "/" + name
	}

	return strings.TrimRight(parentPath, "/") + "/" + name
}

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

func isWritableProjectionPath(projectionPath string) bool {
	return projectionPath == "/tonel" || strings.HasPrefix(projectionPath, "/tonel/")
}

func isProjectedTonelFilePath(projectionPath string) bool {
	if strings.HasPrefix(path.Base(projectionPath), "._") {
		return false
	}

	return strings.HasPrefix(projectionPath, "/tonel/") &&
		(strings.HasSuffix(path.Base(projectionPath), ".class.st") ||
			strings.HasSuffix(path.Base(projectionPath), ".extension.st"))
}
