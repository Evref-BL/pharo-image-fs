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

- macOS with [macFUSE](https://macfuse.github.io/) installed
- Go
- a Pharo image with the `PharoImageFS` package loaded

The current daemon uses macFUSE. The architecture keeps the Go mount layer
separate from Pharo semantics so other backends can be added later.

macFUSE supports two backends:

- the kernel backend, which is the established default and may require enabling
  the macFUSE kernel extension in macOS Recovery;
- the FSKit backend, available in recent macFUSE releases on macOS 26+, which
  runs in user space and avoids the kernel-extension approval path for supported
  file systems.

Use the FSKit backend on macOS 26+ with:

```sh
daemon/pharo-image-fs --mount-option backend=fskit --endpoint http://127.0.0.1:9013/projection /tmp/pharo-image-fs
```

If FSKit is unavailable or does not work for your setup, omit the
`--mount-option backend=fskit` option to use macFUSE's default backend.

## Load the Pharo backend

Load the project in a Pharo image:

```smalltalk
Metacello new
	baseline: 'PharoImageFS';
	repository: 'github://Evref-BL/pharo-image-fs:main/src';
	load
```

The baseline groups are:

- `Core`: projection backend and HTTP endpoint
- `Tests`: backend tests
- `default`: `Core` and `Tests`

## Build the daemon

From a checkout of this repository:

```sh
go -C daemon build -o pharo-image-fs ./cmd/pharo-image-fs
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
daemon/pharo-image-fs --endpoint http://127.0.0.1:9013/projection /tmp/pharo-image-fs
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

Moving projected `.class.st` files across package directories is supported when
the class filename stays the same. The class is moved in the live image, and
both source and target packages are exported.

Renaming projected `.class.st` files inside the same package is supported. The
class is renamed in the live image, same-package references are updated, and the
package is exported.

Combined cross-package move plus class rename and `.extension.st` rename are not
supported.

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
daemon/
  cmd/pharo-image-fs/   Go mount daemon entry point
  pkg/mount/            Filesystem-facing daemon code
  pkg/protocol/         Daemon-to-Pharo projection protocol

src/
  BaselineOfPharoImageFS/
  PharoImageFS/
  PharoImageFS-Tests/
```

## Development goals

The useful next improvements are:

- package the daemon and Pharo backend so installation is less manual;
- make startup/shutdown easier from Pharo and from shell scripts;
- improve write diagnostics so editor and CLI users can see critique feedback
  without checking daemon logs;
- support combined cross-package class move plus class rename;
- add broader transaction coverage for failure paths;
- add more useful critique projections;
- evaluate Linux and Windows mount backends after the macOS workflow is stable.
