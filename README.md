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
- a Pharo image with the `PharoImageFS` package loaded

Build the daemon:

```sh
cd go
go build ./...
```

Run the daemon:

```sh
go run ./cmd/pharo-image-fs --endpoint http://127.0.0.1:9013/projection /tmp/pharo-image-fs
```

Start the Pharo-side projection endpoint in the image first:

```smalltalk
PharoImageFSProjectionHTTPServer startOn: 9013
```

The mountpoint directory is created automatically when missing. The endpoint is
the Pharo-side projection protocol root. The daemon calls these JSON endpoints
under it:

- `POST /list` with `{ "path": "/tonel" }`
- `POST /stat` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" }`
- `POST /read` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" }`
- `POST /write` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st", "text": "..." }`
- `POST /delete` with `{ "path": "/tonel/PharoImageFS/Old.class.st" }`
- `POST /rename` with `{ "path": "/tonel/PharoImageFS/Old.class.st", "targetPath": "/tonel/PharoImageFS/New.class.st" }`

## V1 write semantics

`/tonel` accepts full-file writes for:

- existing `.class.st` files;
- existing `.extension.st` files;
- new `.class.st` files whose Tonel class definition matches the projection
  path;
- new `.extension.st` files for existing classes.

Editor-safe temporary-file create/write/rename save patterns are supported by
the daemon. Temporary files stay local to the daemon until they are renamed over
a real projected Tonel path, where the full file is sent to Pharo as one
transactional write.

Deleting or renaming real projected code files is explicit but unsupported in
V1. It returns the Pharo-side unsupported-write error instead of silently
modifying the image.

`/critiques` is read-only.
