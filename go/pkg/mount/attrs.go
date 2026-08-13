package mount

import (
	"syscall"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
	"github.com/hanwen/go-fuse/v2/fs"
	"github.com/hanwen/go-fuse/v2/fuse"
)

func fillEntry(out *fuse.EntryOut, entry protocol.Entry) {
	fillAttr(&out.Attr, entry)
}

func fillAttr(out *fuse.Attr, entry protocol.Entry) {
	out.Mode = modeForEntry(entry)
	out.Size = entry.Size
	if entry.Kind == protocol.Directory {
		out.Nlink = 2
		return
	}

	out.Nlink = 1
}

func stableAttrFor(entry protocol.Entry) fs.StableAttr {
	return fs.StableAttr{Mode: stableModeFor(entry)}
}

func stableModeFor(entry protocol.Entry) uint32 {
	switch entry.Kind {
	case protocol.Directory:
		return syscall.S_IFDIR
	default:
		return syscall.S_IFREG
	}
}

func modeForEntry(entry protocol.Entry) uint32 {
	return modeForKind(entry.Kind, entry.Writable)
}

func modeForKind(kind protocol.EntryKind, writable bool) uint32 {
	switch kind {
	case protocol.Directory:
		return syscall.S_IFDIR | 0o555
	default:
		if writable {
			return syscall.S_IFREG | 0o644
		}
		return syscall.S_IFREG | 0o444
	}
}

func openFlagsAreWritable(flags uint32) bool {
	accessMode := flags & syscall.O_ACCMODE
	return accessMode == syscall.O_WRONLY || accessMode == syscall.O_RDWR
}

func openFlagsTruncate(flags uint32) bool {
	return flags&syscall.O_TRUNC != 0
}
