package mount

import (
	"context"
	"path"
	"sort"
	"strings"
	"syscall"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
)

// Node is one lazily resolved projected filesystem node.
type Node struct {
	fs.Inode
	client  protocol.Client
	overlay *Overlay
	logger  projectionLogger
	path    string
	entry   protocol.Entry
}

type projectionLogger interface {
	Printf(format string, args ...any)
}

var _ fs.InodeEmbedder = (*Node)(nil)
var _ fs.NodeLookuper = (*Node)(nil)
var _ fs.NodeReaddirer = (*Node)(nil)
var _ fs.NodeGetattrer = (*Node)(nil)
var _ fs.NodeOpener = (*Node)(nil)
var _ fs.NodeAccesser = (*Node)(nil)
var _ fs.NodeCreater = (*Node)(nil)
var _ fs.NodeUnlinker = (*Node)(nil)
var _ fs.NodeRenamer = (*Node)(nil)

// NewRoot answers the root node for a projection client.
func NewRoot(client protocol.Client) *Node {
	return &Node{
		client:  client,
		overlay: NewOverlay(),
		path:    "/",
		entry: protocol.Entry{
			Name: "/",
			Kind: protocol.Directory,
		},
	}
}

func (n *Node) Lookup(ctx context.Context, name string, out *fuse.EntryOut) (*fs.Inode, syscall.Errno) {
	childPath := joinProjectionPath(n.path, name)
	if entry, ok := n.overlay.Stat(childPath); ok {
		entry = writableEntryForPath(childPath, entry)
		fillEntry(out, entry)
		return n.NewInode(ctx, n.childNode(childPath, entry), stableAttrFor(entry)), 0
	}

	entry, err := n.client.Stat(ctx, childPath)
	if err != nil {
		return nil, errnoFor(err)
	}

	entry = writableEntryForPath(childPath, entry)
	fillEntry(out, entry)
	return n.NewInode(ctx, n.childNode(childPath, entry), stableAttrFor(entry)), 0
}

func (n *Node) Readdir(ctx context.Context) (fs.DirStream, syscall.Errno) {
	if n.entry.Kind != protocol.Directory {
		return nil, syscall.ENOTDIR
	}

	entries, err := n.client.List(ctx, n.path)
	if err != nil {
		return nil, errnoFor(err)
	}

	entries = mergeEntries(entries, n.overlay.EntriesIn(n.path))
	dirEntries := make([]fuse.DirEntry, 0, len(entries))
	for _, entry := range entries {
		entry = writableEntryForPath(joinProjectionPath(n.path, entry.Name), entry)
		dirEntries = append(dirEntries, fuse.DirEntry{
			Name: entry.Name,
			Mode: stableModeFor(entry),
		})
	}

	return fs.NewListDirStream(dirEntries), 0
}

func (n *Node) Getattr(ctx context.Context, _ fs.FileHandle, out *fuse.AttrOut) syscall.Errno {
	entry := n.entry
	if n.path != "/" {
		if overlayEntry, ok := n.overlay.Stat(n.path); ok {
			overlayEntry = writableEntryForPath(n.path, overlayEntry)
			fillAttr(&out.Attr, overlayEntry)
			return 0
		}

		refreshedEntry, err := n.client.Stat(ctx, n.path)
		if err != nil {
			return errnoFor(err)
		}
		entry = writableEntryForPath(n.path, refreshedEntry)
	}

	fillAttr(&out.Attr, entry)
	return 0
}

func (n *Node) Open(ctx context.Context, flags uint32) (fs.FileHandle, uint32, syscall.Errno) {
	if n.entry.Kind == protocol.Directory {
		return nil, 0, syscall.EISDIR
	}

	writable := openFlagsAreWritable(flags)
	if writable && !n.entry.Writable {
		return nil, 0, syscall.EROFS
	}

	contents := []byte{}
	if !openFlagsTruncate(flags) {
		if overlayContents, ok := n.overlay.Read(n.path); ok {
			contents = overlayContents
		} else {
			readContents, err := n.client.Read(ctx, n.path)
			if err != nil {
				return nil, 0, errnoFor(err)
			}
			contents = readContents
		}
	}

	handle := &FileHandle{
		client:   n.client,
		path:     n.path,
		contents: contents,
		writable: writable,
		dirty:    openFlagsTruncate(flags),
		flush:    n.writeProjection,
	}

	return handle, fuse.FOPEN_DIRECT_IO, 0
}

func (n *Node) Access(_ context.Context, mask uint32) syscall.Errno {
	entry := writableEntryForPath(n.path, n.entry)
	if mask&2 != 0 && !entry.Writable {
		return syscall.EROFS
	}

	return 0
}

func (n *Node) Create(ctx context.Context, name string, flags uint32, _ uint32, out *fuse.EntryOut) (*fs.Inode, fs.FileHandle, uint32, syscall.Errno) {
	if n.entry.Kind != protocol.Directory {
		return nil, nil, 0, syscall.ENOTDIR
	}

	childPath := joinProjectionPath(n.path, name)
	if !isWritableProjectionPath(childPath) {
		return nil, nil, 0, syscall.EROFS
	}

	if _, ok := n.overlay.Stat(childPath); ok {
		return nil, nil, 0, syscall.EEXIST
	}
	if _, err := n.client.Stat(ctx, childPath); err == nil {
		return nil, nil, 0, syscall.EEXIST
	} else if !protocol.NotFound(err) {
		return nil, nil, 0, errnoFor(err)
	}

	n.overlay.Create(childPath, nil)
	entry, _ := n.overlay.Stat(childPath)
	fillEntry(out, entry)

	writable := openFlagsAreWritable(flags)
	handle := &FileHandle{
		path:     childPath,
		contents: []byte{},
		writable: writable,
		flush:    n.overlay.Write,
	}

	return n.NewInode(ctx, n.childNode(childPath, entry), stableAttrFor(entry)), handle, fuse.FOPEN_DIRECT_IO, 0
}

func (n *Node) Unlink(_ context.Context, name string) syscall.Errno {
	childPath := joinProjectionPath(n.path, name)
	if n.overlay.Delete(childPath) {
		return 0
	}

	if isWritableProjectionPath(childPath) {
		return syscall.ENOTSUP
	}

	return syscall.EROFS
}

func (n *Node) Rename(ctx context.Context, name string, newParent fs.InodeEmbedder, newName string, flags uint32) syscall.Errno {
	if flags != 0 {
		return syscall.ENOTSUP
	}

	targetParent, ok := newParent.(*Node)
	if !ok {
		return syscall.EINVAL
	}

	oldPath := joinProjectionPath(n.path, name)
	newPath := joinProjectionPath(targetParent.path, newName)
	contents, ok := n.overlay.Read(oldPath)
	if !ok {
		return syscall.ENOTSUP
	}

	if isProjectedTonelFilePath(newPath) {
		if err := n.writeProjection(ctx, newPath, contents); err != nil {
			return errnoFor(err)
		}
		n.overlay.Delete(oldPath)
		n.overlay.Delete(newPath)
		return 0
	}

	if !isWritableProjectionPath(newPath) {
		return syscall.EROFS
	}

	n.overlay.Move(oldPath, newPath)
	return 0
}

func joinProjectionPath(parentPath string, name string) string {
	if parentPath == "/" {
		return "/" + name
	}

	return strings.TrimRight(parentPath, "/") + "/" + name
}

func (n *Node) childNode(childPath string, entry protocol.Entry) *Node {
	return &Node{
		client:  n.client,
		overlay: n.overlay,
		logger:  n.logger,
		path:    childPath,
		entry:   entry,
	}
}

func (n *Node) writeProjection(ctx context.Context, projectionPath string, contents []byte) error {
	result, err := n.client.Write(ctx, projectionPath, contents)
	if err != nil {
		n.logf("write %s failed: %v", projectionPath, err)
		return err
	}

	n.logDiagnostics(projectionPath, result.Diagnostics)
	return nil
}

func (n *Node) logDiagnostics(projectionPath string, diagnostics []protocol.Diagnostic) {
	if len(diagnostics) == 0 {
		return
	}

	n.logf("write %s returned %d diagnostic(s)", projectionPath, len(diagnostics))
	for _, diagnostic := range diagnostics {
		n.logf("diagnostic %s: %s", diagnostic.Rule, diagnosticLineFor(diagnostic))
	}
}

func (n *Node) logf(format string, args ...any) {
	if n.logger == nil {
		return
	}

	n.logger.Printf(format, args...)
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
	return strings.HasPrefix(projectionPath, "/tonel/") &&
		(strings.HasSuffix(path.Base(projectionPath), ".class.st") ||
			strings.HasSuffix(path.Base(projectionPath), ".extension.st"))
}
