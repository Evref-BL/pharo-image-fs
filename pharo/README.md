# Pharo backend

This directory will contain the Pharo packages that implement live-image
projection semantics for `pharo-image-fs`.

The Pharo backend owns:

- projection path resolution;
- lazy package/class/method listing;
- Tonel rendering from the live image;
- transactional Tonel write application;
- compilation and blocking critique checks;
- non-blocking critique diagnostics;
- synchronization of live image and exported source.

Start a local projection endpoint with:

```smalltalk
PharoImageFSProjectionHTTPServer startOn: 9013
```

V1 supports full-file writes for existing and new Tonel class files, plus
existing and new Tonel extension files. It supports direct deletion of projected
class and extension files. It supports same-package class-file rename and keeps
extension-file rename unsupported until those image semantics are made safe.
