package mount

import (
	"strings"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
)

func diagnosticLineFor(diagnostic protocol.Diagnostic) string {
	parts := make([]string, 0, 3)
	if diagnostic.Severity != "" {
		parts = append(parts, diagnostic.Severity)
	}
	if diagnostic.Title != "" {
		parts = append(parts, diagnostic.Title)
	}
	if diagnostic.Message != "" {
		parts = append(parts, diagnostic.Message)
	}

	return strings.Join(parts, " - ")
}
