package mount

import (
	"context"
	"strings"
	"syscall"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
)

// Node is one lazily resolved projected filesystem node.
type Node struct {
	fs.Inode
	client protocol.Client
	path   string
	entry  protocol.Entry
}

var _ fs.InodeEmbedder = (*Node)(nil)
var _ fs.NodeLookuper = (*Node)(nil)
var _ fs.NodeReaddirer = (*Node)(nil)
var _ fs.NodeGetattrer = (*Node)(nil)
var _ fs.NodeOpener = (*Node)(nil)
var _ fs.NodeAccesser = (*Node)(nil)

// NewRoot answers the root node for a projection client.
func NewRoot(client protocol.Client) *Node {
	return &Node{
		client: client,
		path:   "/",
		entry: protocol.Entry{
			Name: "/",
			Kind: protocol.Directory,
		},
	}
}

func (n *Node) Lookup(ctx context.Context, name string, out *fuse.EntryOut) (*fs.Inode, syscall.Errno) {
	childPath := joinProjectionPath(n.path, name)
	entry, err := n.client.Stat(ctx, childPath)
	if err != nil {
		return nil, errnoFor(err)
	}

	fillEntry(out, entry)
	return n.NewInode(ctx, &Node{
		client: n.client,
		path:   childPath,
		entry:  entry,
	}, stableAttrFor(entry)), 0
}

func (n *Node) Readdir(ctx context.Context) (fs.DirStream, syscall.Errno) {
	if n.entry.Kind != protocol.Directory {
		return nil, syscall.ENOTDIR
	}

	entries, err := n.client.List(ctx, n.path)
	if err != nil {
		return nil, errnoFor(err)
	}

	dirEntries := make([]fuse.DirEntry, 0, len(entries))
	for _, entry := range entries {
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
		refreshedEntry, err := n.client.Stat(ctx, n.path)
		if err != nil {
			return errnoFor(err)
		}
		entry = refreshedEntry
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
		readContents, err := n.client.Read(ctx, n.path)
		if err != nil {
			return nil, 0, errnoFor(err)
		}
		contents = readContents
	}

	handle := &FileHandle{
		client:   n.client,
		path:     n.path,
		contents: contents,
		writable: writable,
		dirty:    openFlagsTruncate(flags),
	}

	return handle, fuse.FOPEN_DIRECT_IO, 0
}

func (n *Node) Access(_ context.Context, mask uint32) syscall.Errno {
	if mask&2 != 0 && !n.entry.Writable {
		return syscall.EROFS
	}

	return 0
}

func joinProjectionPath(parentPath string, name string) string {
	if parentPath == "/" {
		return "/" + name
	}

	return strings.TrimRight(parentPath, "/") + "/" + name
}
