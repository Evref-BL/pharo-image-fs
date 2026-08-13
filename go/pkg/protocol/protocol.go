package protocol

// Entry describes one projected filesystem entry returned by Pharo.
type Entry struct {
	Name string
	Kind EntryKind
}

// EntryKind identifies the filesystem kind of a projected entry.
type EntryKind string

const (
	Directory EntryKind = "directory"
	File      EntryKind = "file"
)

// Client is the narrow daemon-to-Pharo projection protocol.
type Client interface {
	List(path string) ([]Entry, error)
	Stat(path string) (Entry, error)
	Read(path string) ([]byte, error)
	Write(path string, contents []byte) error
}
