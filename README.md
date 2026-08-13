# pharo-image-fs

`pharo-image-fs` exposes a live Pharo image as a local filesystem.

It gives LLM agents and developer tools one normal code-editing path: use `rg`,
diff, patch, editors, and other filesystem tools against a mounted projection.
Pharo remains authoritative for Pharo semantics: source projection, parsing,
compilation, transactional writes, Tonel export/sync, and critique feedback.

## What the mount exposes

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

- `/tonel` is the code editing surface. It mirrors Tonel class and extension
  files from the live image.
- `/critiques` is read-only diagnostic feedback from the live image.

## Requirements

- macOS with macFUSE installed and enabled
- Go
- a Pharo image with the `PharoImageFS` package loaded

The current daemon uses macFUSE. The architecture keeps the Go mount layer
separate from Pharo semantics so other backends can be added later.

## Load the Pharo backend

Load the project from the repository root:

```smalltalk
Metacello new
	baseline: 'PharoImageFS';
	repository: 'tonel://pharo/src';
	load
```

The baseline groups are:

- `Core`: projection backend and HTTP endpoint
- `Tests`: backend tests
- `default`: `Core` and `Tests`

## Build the daemon

```sh
cd go
go build -o pharo-image-fs ./cmd/pharo-image-fs
```

## Start the projection

Start the Pharo-side projection endpoint in the image:

```smalltalk
PharoImageFSProjectionHTTPServer startOn: 9013
```

Stop it from Pharo with:

```smalltalk
PharoImageFSProjectionHTTPServer stopOn: 9013
```

Use `PharoImageFSProjectionHTTPServer stopAll` to stop every projection server
started through this API.

Then mount the image from a terminal:

```sh
./go/pharo-image-fs --endpoint http://127.0.0.1:9013/projection /tmp/pharo-image-fs
```

The mountpoint directory is created automatically when missing.

Unmount with the normal macOS unmount command:

```sh
umount /tmp/pharo-image-fs
```

If macFUSE reports the mount as busy, use:

```sh
diskutil unmount /tmp/pharo-image-fs
```

## Use the mounted image

Read and search Pharo code with normal file tools:

```sh
rg "projection" /tmp/pharo-image-fs/tonel
sed -n '1,120p' /tmp/pharo-image-fs/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st
```

Edit projected Tonel files with an editor or patch tool. Successful writes are
compiled in the live image and exported back to Tonel. If parsing, compilation,
or blocking critiques fail, the write is rejected and the previous image state
is restored.

Read critique feedback:

```sh
cat /tmp/pharo-image-fs/critiques/PharoImageFSProjectionBackend.json
cat /tmp/pharo-image-fs/critiques/PharoImageFSProjectionBackend/write:at:.json
```

## Supported code operations

`/tonel` accepts full-file writes for:

- existing `.class.st` files;
- existing `.extension.st` files;
- new `.class.st` files whose Tonel class definition matches the projection
  path;
- new `.extension.st` files for existing classes.

Editor-safe temporary-file save patterns are supported. Temporary files stay
local to the daemon until they are renamed over a real projected Tonel path,
where the full file is sent to Pharo as one transactional write.

Deleting projected code files is supported for `.class.st` and `.extension.st`.
Class-file deletion removes the class from the image. Extension-file deletion
removes only extension methods for that class/package.

Renaming projected `.class.st` files inside the same package is supported. The
class is renamed in the live image, same-package references are updated, and the
package is exported. Cross-package class rename and `.extension.st` rename are
not supported.

`/critiques` is read-only.

## Projection protocol

The Go daemon talks to the Pharo endpoint through a narrow JSON protocol:

- `POST /list` with `{ "path": "/tonel" }`
- `POST /stat` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" }`
- `POST /read` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" }`
- `POST /write` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st", "text": "..." }`
- `POST /delete` with `{ "path": "/tonel/PharoImageFS/Old.class.st" }`
- `POST /rename` with `{ "path": "/tonel/PharoImageFS/Old.class.st", "targetPath": "/tonel/PharoImageFS/New.class.st" }`

The daemon does not parse or validate Pharo code. It owns mount lifecycle,
filesystem callbacks, transport, timeouts, and generic errors. The Pharo backend
owns source rendering, write transactions, compilation, critiques, and export.

## Project layout

```text
go/
  cmd/pharo-image-fs/   Go mount daemon entry point
  pkg/mount/            Filesystem-facing daemon code
  pkg/protocol/         Daemon-to-Pharo projection protocol

pharo/
  src/                  Pharo backend packages
```

## Development goals

The useful next improvements are:

- package the daemon and Pharo backend so installation is less manual;
- make startup/shutdown easier from Pharo and from shell scripts;
- improve write diagnostics so editor and CLI users can see critique feedback
  without checking daemon logs;
- add broader transaction coverage for failure paths;
- add more useful critique projections;
- evaluate Linux and Windows mount backends after the macOS workflow is stable.
