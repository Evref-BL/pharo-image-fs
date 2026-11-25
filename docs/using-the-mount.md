# Using the mount

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

## Use the mounted image

Read and search Pharo code with normal file tools:

```sh
rg "projection" /tmp/pharo-image-fs/tonel
sed -n '1,120p' /tmp/pharo-image-fs/tonel/PharoImageFS/PIFSBackend.class.st
```

Edit projected Tonel files with an editor or patch tool. Successful writes are
compiled in the live image and exported back to Tonel. If parsing, compilation,
or blocking critiques fail, the write is rejected and the previous image state
is restored.

Read critique feedback for code edited through the projection:

```sh
find /tmp/pharo-image-fs/critiques -type f
cat /tmp/pharo-image-fs/critiques/PharoImageFS/PIFSBackend/write.at..json
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
exported coherently. The default repository-ownership check rejects writes to
packages that are not attached to a loaded, file-backed Iceberg repository. If
the package is visible in the image but has no writable checkout, either attach
it to an Iceberg repository first or explicitly disable repository ownership
checks for live-image-only writes.

The projection is lazy and backed by the live image. Directory listings, stat
requests, and reads ask Pharo for the current state as the filesystem needs
them, so image-side changes become visible through the mount on later
filesystem operations. Filesystem metadata caches are intentionally short; an
already-open file handle can still contain the contents read when it was opened.

## Supported code operations

`/tonel` accepts full-file writes for:

- existing `.class.st` files;
- existing `.extension.st` files;
- new `.class.st` files whose Tonel class definition matches the projection
  path, creating the package when repository-ownership checks are disabled;
- new `.extension.st` files for existing classes.

Class names are global, so a `.class.st` file of a class that lives in another
package is refused. When that package is projected, the error names the move of
the class's file that puts it there.

`/tonel/<Package>` directories can be created and removed. Creating a directory
creates a package in the live image when repository-ownership checks are
disabled. With the default checks enabled, creating or removing a package that
has no file-backed repository owner is rejected with a clear error. Removing a
directory removes the package only when it is empty; delete class and extension
files explicitly first.

Editor-safe temporary-file save patterns are supported. Temporary files stay
local to the daemon until they are renamed over a real projected Tonel path,
where the full file is sent to Pharo as one transactional write.

The write protocol sends full Tonel file contents, but the Pharo backend parses
the old and new definitions and only applies definitions that changed. Unchanged
methods are left untouched.

Deleting projected code files is supported for `.class.st` and `.extension.st`.
Class-file deletion removes the class from the image. Extension-file deletion
removes only extension methods for that class/package. Removing an empty package
directory removes the package from the image, and from the checkout and Iceberg
working copy of the repository that owns it.

Moving projected `.class.st` files across package directories is supported. The
class is moved in the live image. With the default repository-ownership check,
both source and target packages must belong to loaded Iceberg repositories.

Renaming projected `.class.st` files inside the same package is supported. The
class is renamed in the live image, its references are updated, and the package
is exported. In other packages, the files the rename changes are exported: those
of the methods that refer to the class or name it in a symbol, of the classes
whose definition names it, as their superclass, a pool, a trait, or the class of
a slot or a class variable, and its extension files, which take the new name.
Those packages must be projected and, with the default repository-ownership
check, belong to loaded Iceberg repositories. Methods that already named the new
name are bound to the renamed class.

Combined cross-package move plus class rename is supported.

Moving projected `.extension.st` files across package directories is supported
when the extension filename stays the same. The extension method protocols are
rewritten from the source package to the target package. With the default
repository-ownership check, both source and target packages must belong to
loaded Iceberg repositories.

Renaming projected `.extension.st` files is not supported.

`/critiques` is read-only.

`/errors` is read-only and records a small in-memory history of operation
failures, plus `latest.txt`.

`/repositories` is read-only from the projection point of view. Each loaded
Iceberg repository is exposed as a symlink to its real checkout plus a
`<repository>.repository.json` metadata file. Following a symlink reaches the
normal Git checkout on disk.
