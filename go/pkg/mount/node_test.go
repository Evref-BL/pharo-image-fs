package mount

import (
	"testing"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/protocol"
)

func TestRootReaddirUsesProjectionClient(t *testing.T) {
	client := &fakeClient{
		entries: map[string][]protocol.Entry{
			"/": {
				{Name: "tonel", Kind: protocol.Directory},
				{Name: "critiques", Kind: protocol.Directory},
			},
		},
	}
	root := NewRoot(client)

	stream, errno := root.Readdir(t.Context())
	if errno != 0 {
		t.Fatalf("readdir errno: %v", errno)
	}

	names := dirStreamNames(t, stream)
	if len(names) != 2 || names[0] != "tonel" || names[1] != "critiques" {
		t.Fatalf("unexpected entries: %#v", names)
	}
}
