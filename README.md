# pharo-image-fs

`pharo-image-fs` exposes a live Pharo image as a local filesystem.

It gives LLM agents and developer tools one normal code-editing path: use `rg`,
diff, patch, editors, and other filesystem tools against a mounted projection.
Pharo remains authoritative for Pharo semantics: source projection, parsing,
compilation, transactional writes, Tonel export/sync, and critique feedback.

Use this alongside [MCP-Pharo](https://github.com/Evref-BL/MCP) when available:
`pharo-image-fs` is the normal file-editing surface, while MCP tools remain the
better interface for semantic operations such as refactorings, test runs,
critique runs, and repository operations.

## Requirements

- macOS with [fuse-t](https://www.fuse-t.org/) installed
- a Pharo image where the `PharoImageFS` package can be loaded

On macOS, fuse-t can be installed with Homebrew:

```sh
brew install --cask fuse-t
```

If fuse-t was partially uninstalled and Homebrew still considers it installed,
restore the expected files with:

```sh
brew reinstall --cask fuse-t
```

The daemon is built and released from
[`pharo-image-fs-daemon`](https://github.com/Evref-BL/pharo-image-fs-daemon).
`pharo-image-fs` downloads the matching prebuilt daemon binary when needed.
Prebuilt daemon binaries do not require Go at runtime, but the platform FUSE
dependency is still required.

## Usage

### Load the Pharo backend

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

### Daemon binary

By default, the Pharo backend downloads the matching daemon release into its
local cache before starting the mount. For local development, set
`PHARO_IMAGE_FS_DAEMON` to a daemon executable path to bypass the download.

### Start the projection

Start the Pharo-side projection endpoint and daemon from the image:

```smalltalk
PharoImageFSProjectionHTTPServer startAndMountOn: 9013
```

To use the default mountpoint with an explicit volume name:

```smalltalk
PharoImageFSProjectionHTTPServer
	startOn: 9013
	mountNamed: 'pharo-image-fs'
```

To use an explicit mountpoint and volume name:

```smalltalk
PharoImageFSProjectionHTTPServer
	startOn: 9013
	mountAt: '/tmp/pharo-image-fs' asFileReference
	named: 'pharo-image-fs'
```

Stop it from Pharo with:

```smalltalk
PharoImageFSProjectionHTTPServer stopOn: 9013
```

Use `PharoImageFSProjectionHTTPServer stopAll` to stop every projection server
started through this API.

The mountpoint path is created when it is missing. If the path already exists,
it must be a directory.

The daemon requires fuse-t on macOS. fuse-t provides a FUSE-compatible API
without requiring the macFUSE kernel extension security flow.

Unmount with the normal macOS unmount command:

```sh
umount /tmp/pharo-image-fs
```

If macOS reports the mount as busy, use:

```sh
diskutil unmount /tmp/pharo-image-fs
```

### Use the mounted image

Read and search Pharo code with normal file tools:

```sh
rg "projection" /tmp/pharo-image-fs/tonel
sed -n '1,120p' /tmp/pharo-image-fs/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st
```

Edit projected Tonel files with an editor or patch tool. Successful writes are
compiled in the live image and exported back to Tonel. If parsing, compilation,
or blocking critiques fail, the write is rejected and the previous image state
is restored.

Read critique feedback for code edited through the projection:

```sh
find /tmp/pharo-image-fs/critiques -type f
cat /tmp/pharo-image-fs/critiques/PharoImageFS/PharoImageFSProjectionBackend/write.at..json
```

`/critiques` does not scan the whole image. Accepted writes through `/tonel`
refresh critique files for the affected class or extension methods only, and
files appear only when actual Pharo critiques exist.

If a filesystem write fails with a generic editor or OS error, inspect the
latest operational error:

```sh
cat /tmp/pharo-image-fs/errors/latest.txt
```

`/errors` is intentionally small and only contains mount/projection operation
failures that are otherwise hard to see from filesystem tools. Pharo critiques
remain under `/critiques` only.

Inspect the loaded Git checkouts through repository symlinks:

```sh
ls -l /tmp/pharo-image-fs/repositories
git -C /tmp/pharo-image-fs/repositories/pharo-image-fs status
cat /tmp/pharo-image-fs/repositories/pharo-image-fs.repository.json
```

Use `/repositories` for repository operations and non-image files such as docs.
For Pharo code, edit `/tonel` so writes are compiled in the live image and
exported coherently when the package belongs to a loaded Iceberg repository.

The projection is lazy and backed by the live image. Directory listings, stat
requests, and reads ask Pharo for the current state as the filesystem needs
them, so image-side changes become visible through the mount on later
filesystem operations. Filesystem metadata caches are intentionally short; an
already-open file handle can still contain the contents read when it was opened.

### Supported code operations

`/tonel` accepts full-file writes for:

- existing `.class.st` files;
- existing `.extension.st` files;
- new `.class.st` files whose Tonel class definition matches the projection
  path, creating the package when necessary;
- new `.extension.st` files for existing classes.

`/tonel/<Package>` directories can be created and removed. Creating a directory
creates a package in the live image. Removing a directory removes the package
only when it is empty; delete class and extension files explicitly first.

Editor-safe temporary-file save patterns are supported. Temporary files stay
local to the daemon until they are renamed over a real projected Tonel path,
where the full file is sent to Pharo as one transactional write.

The write protocol sends full Tonel file contents, but the Pharo backend parses
the old and new definitions and only applies definitions that changed. Unchanged
methods are left untouched.

Deleting projected code files is supported for `.class.st` and `.extension.st`.
Class-file deletion removes the class from the image. Extension-file deletion
removes only extension methods for that class/package.

Moving projected `.class.st` files across package directories is supported. The
class is moved in the live image. Source and target packages are exported when
they belong to loaded Iceberg repositories.

Renaming projected `.class.st` files inside the same package is supported. The
class is renamed in the live image, same-package references are updated, and the
package is exported when it belongs to a loaded Iceberg repository.

Combined cross-package move plus class rename is supported.

Moving projected `.extension.st` files across package directories is supported
when the extension filename stays the same. The extension method protocols are
rewritten from the source package to the target package. Source and target
packages are exported when they belong to loaded Iceberg repositories.

Renaming projected `.extension.st` files is not supported.

`/critiques` is read-only.

`/errors` is read-only and records a small in-memory history of operation
failures, plus `latest.txt`.

`/repositories` is read-only from the projection point of view. Each loaded
Iceberg repository is exposed as a symlink to its real checkout plus a
`<repository>.repository.json` metadata file. Following a symlink reaches the
normal Git checkout on disk.

## What the mount exposes

```text
/
  tonel/
    <package>/
      <Class>.class.st
      <Class>.extension.st

  critiques/
    <package>/
      <Class>/
        class-critiques.json
        <selector-encoded>.json

  errors/
    latest.txt
    <timestamp>-write.txt

  repositories/
    <repository> -> /absolute/path/to/checkout
    <repository>.repository.json
```

- `/tonel` is the code editing surface. It mirrors Tonel class and extension
  files from the live image.
- `/critiques` is read-only diagnostic feedback for code edited through the
  projection. It does not scan the whole image; accepted writes refresh entries
  for the affected class or extension methods, and entries appear only when
  actual Pharo critiques exist.
  Keyword-selector colons are encoded as dots, and binary selector characters
  use caret escape names, for example `responseObjectForOperation.request..json`
  and `^slash.json`.
- `/errors` is read-only operational feedback for failed projection writes.
- `/repositories` exposes loaded Iceberg repositories as symlinks to their real
  checkout directories, plus small metadata files listing the repository name,
  projection name, path, and loaded packages.

## Projection protocol

The Go daemon talks to the Pharo endpoint through a narrow JSON protocol:

- `POST /list` with `{ "path": "/tonel" }`
- `POST /stat` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" }`
- `POST /read` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st" }`
- `POST /write` with `{ "path": "/tonel/PharoImageFS/PharoImageFSProjectionBackend.class.st", "text": "..." }`
- `POST /delete` with `{ "path": "/tonel/PharoImageFS/Old.class.st" }`
- `POST /rename` with `{ "path": "/tonel/PharoImageFS/Old.class.st", "targetPath": "/tonel/PharoImageFS/New.class.st" }`
- `POST /mkdir` with `{ "path": "/tonel/NewPackage" }`
- `POST /rmdir` with `{ "path": "/tonel/OldPackage" }`

The daemon does not parse or validate Pharo code. It owns mount lifecycle,
filesystem callbacks, transport, timeouts, and generic errors. The Pharo backend
owns source rendering, write transactions, compilation, critiques, and export.

Matching project releases use the same version number. The Pharo package keeps
its expected daemon version in `PharoImageFSVersion`.

## Development goals

The useful next improvements are:

- evaluate Linux and Windows mount backends after the macOS workflow is stable.
