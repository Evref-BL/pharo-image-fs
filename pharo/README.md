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

