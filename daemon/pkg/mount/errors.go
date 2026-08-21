package mount

import (
	"fmt"
	"path"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
)

const (
	errorsRoot      = "/errors"
	latestErrorName = "latest.txt"
	maxErrorEntries = 10
)

type ErrorStore struct {
	mu      sync.Mutex
	entries []errorEntry
}

type errorEntry struct {
	name     string
	contents []byte
}

func NewErrorStore() *ErrorStore {
	return &ErrorStore{}
}

func (s *ErrorStore) RecordWriteError(projectionPath string, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	entry := errorEntry{
		name:     time.Now().Format("2006-01-02T15-04-05") + "-write.txt",
		contents: []byte(writeErrorTextFor(projectionPath, err)),
	}
	s.entries = append([]errorEntry{entry}, s.entries...)
	if len(s.entries) > maxErrorEntries {
		s.entries = s.entries[:maxErrorEntries]
	}
}

func (s *ErrorStore) Stat(projectionPath string) (protocol.Entry, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	switch projectionPath {
	case errorsRoot:
		return protocol.Entry{Name: path.Base(projectionPath), Kind: protocol.Directory}, true
	case errorsRoot + "/" + latestErrorName:
		if len(s.entries) == 0 {
			return protocol.Entry{}, false
		}
		return protocol.Entry{Name: latestErrorName, Kind: protocol.File, Size: uint64(len(s.entries[0].contents))}, true
	default:
		for _, entry := range s.entries {
			if projectionPath == errorsRoot+"/"+entry.name {
				return protocol.Entry{Name: entry.name, Kind: protocol.File, Size: uint64(len(entry.contents))}, true
			}
		}
		return protocol.Entry{}, false
	}
}

func (s *ErrorStore) EntriesIn(projectionPath string) []protocol.Entry {
	s.mu.Lock()
	defer s.mu.Unlock()

	if projectionPath == "/" {
		return []protocol.Entry{
			{Name: path.Base(errorsRoot), Kind: protocol.Directory},
		}
	}
	if projectionPath != errorsRoot || len(s.entries) == 0 {
		return nil
	}

	entries := make([]protocol.Entry, 0, len(s.entries)+1)
	entries = append(entries, protocol.Entry{
		Name: latestErrorName,
		Kind: protocol.File,
		Size: uint64(len(s.entries[0].contents)),
	})
	for _, entry := range s.entries {
		entries = append(entries, protocol.Entry{
			Name: entry.name,
			Kind: protocol.File,
			Size: uint64(len(entry.contents)),
		})
	}
	sort.Slice(entries[1:], func(i int, j int) bool {
		return entries[i+1].Name > entries[j+1].Name
	})
	return entries
}

func (s *ErrorStore) Read(projectionPath string) ([]byte, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if projectionPath == errorsRoot+"/"+latestErrorName {
		if len(s.entries) == 0 {
			return nil, false
		}
		return append([]byte(nil), s.entries[0].contents...), true
	}

	for _, entry := range s.entries {
		if projectionPath == errorsRoot+"/"+entry.name {
			return append([]byte(nil), entry.contents...), true
		}
	}
	return nil, false
}

func writeErrorTextFor(projectionPath string, err error) string {
	message := "unknown error"
	if err != nil {
		message = err.Error()
	}

	return fmt.Sprintf(
		"Operation: write\nPath: %s\nImage changed: no\n\n%s\n",
		projectionPath,
		strings.TrimSpace(message))
}
