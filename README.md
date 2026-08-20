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

- macOS with [macFUSE](https://macfuse.github.io/) installed
- Go
- a Pharo image where the `PharoImageFS` package can be loaded

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

### Build the daemon

From a checkout of this repository:

```sh
go -C daemon build -o pharo-image-fs ./cmd/pharo-image-fs
```

### Start the projection

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

Then mount the image from a terminal. The mountpoint path is created when it is
missing. If the path already exists, it must be a directory.

```sh
daemon/pharo-image-fs --endpoint http://127.0.0.1:9013/projection /tmp/pharo-image-fs
```

Use the same port in both commands. For example, if the Pharo endpoint runs on
`9023`, mount with:

```sh
daemon/pharo-image-fs --endpoint http://127.0.0.1:9023/projection /tmp/pharo-image-fs
```

If the daemon reports `mountpoint is not a directory`, the chosen mountpoint path
already exists as a non-directory. Choose another path or remove/rename the
existing file before mounting.

Unmount with the normal macOS unmount command:

```sh
umount /tmp/pharo-image-fs
```

If macFUSE reports the mount as busy, use:

```sh
diskutil unmount /tmp/pharo-image-fs
```

macFUSE uses its kernel backend by default. On macOS 26+ with a recent macFUSE,
you can opt into the FSKit backend, which runs in user space and avoids the
kernel-extension approval path for supported file systems.

FSKit has two requirements that differ from the kernel backend:

- **Mount points must be under `/Volumes`.** Outside of `/Volumes`, macFUSE
  falls back to the kernel extension.
- **Reduced Security.** macOS classifies FSKit modules as system extensions.
  Even though they run in user space, the Mac's security policy must allow
  third-party system extensions. If your Mac is on Full Security, you need to
  change it once: shut down, hold Touch ID / power button to enter Startup
  Security Utility, select your disk, click **Security Policy**, and choose
  **Reduced Security** (Allow identified developers is sufficient). This is a
  one-time change.

**First-time FSKit setup.** After setting the security policy, approve the
macFUSE FSKit extensions from a terminal:

```sh
pluginkit -e use -p com.apple.fskit.fsmodule -i io.macfuse.app.fsmodule.macfuse
pluginkit -e use -p com.apple.fskit.fsmodule -i io.macfuse.app.fsmodule.macfuse-local
```

Then mount under `/Volumes` with the FSKit backend:

```sh
daemon/pharo-image-fs --mount-option backend=fskit --endpoint http://127.0.0.1:9013/projection /Volumes/pharo-image-fs
```

If FSKit is unavailable or does not work for your setup, omit the
`--mount-option backend=fskit` option to use macFUSE's default backend. Without
FSKit, mount points are not restricted to `/Volumes`.

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

Read critique feedback:

```sh
cat /tmp/pharo-image-fs/critiques/PharoImageFSProjectionBackend.json
cat /tmp/pharo-image-fs/critiques/PharoImageFSProjectionBackend/write:at:.json
```

The projection is lazy and backed by the live image. Directory listings, stat
requests, and reads ask Pharo for the current state as the filesystem needs
them, so image-side changes become visible through the mount on later
filesystem operations. macFUSE/go-fuse metadata caches are intentionally short;
an already-open file handle can still contain the contents read when it was
opened.

### Supported code operations

`/tonel` accepts full-file writes for:

- existing `.class.st` files;
- existing `.extension.st` files;
- new `.class.st` files whose Tonel class definition matches the projection
  path;
- new `.extension.st` files for existing classes.

Editor-safe temporary-file save patterns are supported. Temporary files stay
local to the daemon until they are renamed over a real projected Tonel path,
where the full file is sent to Pharo as one transactional write.

The write protocol sends full Tonel file contents, but the Pharo backend parses
the old and new definitions and only applies definitions that changed. Unchanged
methods are left untouched.

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
