# Projection protocol

The Go daemon talks to the Pharo endpoint through a narrow JSON protocol:

- `POST /list` with `{ "path": "/tonel" }`
- `POST /stat` with `{ "path": "/tonel/PharoImageFS/PIFSBackend.class.st" }`
- `POST /read` with `{ "path": "/tonel/PharoImageFS/PIFSBackend.class.st" }`
- `POST /write` with `{ "path": "/tonel/PharoImageFS/PIFSBackend.class.st", "text": "..." }`
- `POST /delete` with `{ "path": "/tonel/PharoImageFS/Old.class.st" }`
- `POST /rename` with `{ "path": "/tonel/PharoImageFS/Old.class.st", "targetPath": "/tonel/PharoImageFS/New.class.st" }`
- `POST /mkdir` with `{ "path": "/tonel/NewPackage" }`
- `POST /rmdir` with `{ "path": "/tonel/OldPackage" }`

The daemon does not parse or validate Pharo code. It owns mount lifecycle,
filesystem callbacks, transport, timeouts, and generic errors. The Pharo backend
owns source rendering, write transactions, compilation, critiques, and export.

Matching project releases use the same version number. The Pharo package keeps
its expected daemon version in `PIFSVersion`.
