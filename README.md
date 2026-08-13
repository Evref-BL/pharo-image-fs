# pharo-image-fs

`pharo-image-fs` projects a live Pharo image as a local filesystem for LLM
agents.

The goal is one normal code-editing path: use regular file tools such as `rg`,
diff, patch, and editors against a mounted filesystem. Pharo remains
authoritative for Pharo semantics, compilation, transactional writes, Tonel
export/sync, and critique feedback.

## Repository layout

```text
go/
  cmd/pharo-image-fs/   Go mount daemon entry point
  pkg/mount/            Filesystem-facing daemon code
  pkg/protocol/         Narrow daemon-to-Pharo projection protocol

pharo/
  src/                  Pharo backend packages
```

## MVP projection

```text
/
  tonel/
    <package>/
      <Class>.class.st
      <Class>.extension.st

  critiques/
    <Class>.json
    <Class>/
      <selector>.json
```

`/tonel` is the only code editing surface. `/critiques` is read-only diagnostic
feedback.

## Design boundary

- Go owns the OS mount lifecycle, macFUSE integration, and filesystem callbacks.
- Pharo owns projection semantics, Tonel rendering, transactional write
  application, compilation, critique feedback, and source synchronization.
- The Go daemon should not parse or validate Pharo code.
- This mount is not an MCP resource and does not add fallback edit tools.

## Development

Requirements:

- Go
- macFUSE on macOS

Build the daemon:

```sh
cd go
go build ./...
```

