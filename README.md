# pharo-image-fs

`pharo-image-fs` exposes a live Pharo image as a local filesystem.

It gives LLM agents and developer tools one normal code-editing path: use `rg`,
diff, patch, editors, and other filesystem tools against a mounted projection.
Pharo remains authoritative for Pharo semantics: source projection, parsing,
compilation, transactional writes, Tonel export/sync, and critique feedback.

Use this alongside [MCP for Pharo](https://github.com/Evref-BL/MCP) when
available: `pharo-image-fs` is the normal file-editing surface, while MCP tools
remain the better interface for semantic operations such as refactorings, test
runs, critique runs, and repository operations.

## Requirements

- macOS, with nothing to install: the daemon serves the projection over NFS
  and mounts it with the system's `mount_nfs`
- or Linux with FUSE: the `fuse3` package's `fusermount3`, and `/dev/fuse`,
  which most desktop and server installs have. Ubuntu 25.04 and later let
  `fusermount3` mount only under the home directory, `/tmp`, `/mnt`, `/media`
  and `/run/user`
- a Pharo image where the `PharoImageFS` package can be loaded

Windows is not supported yet.

The daemon is built and released from
[`pharo-image-fs-daemon`](https://github.com/Evref-BL/pharo-image-fs-daemon).
`pharo-image-fs` downloads the matching prebuilt daemon binary when needed; it
needs nothing else at run time.

## Install

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
- `Tools`: the projection served as MCP tools, for an image that runs an MCP
  server; it loads [MCP](https://github.com/Evref-BL/MCP) and is left out of
  `default`
- `Tools Tests`: tests for those tools

## Use

Start the projection from the image:

```smalltalk
projection := PIFSServer start.
projection mountPath
```

It mounts in the system's temporary directory, under the image's name, and
answers once the mount is there. `mountPath` says where. The mount holds:

```text
/
  tonel/          the image's code, as Tonel files to read and edit
  critiques/      critiques of the code edited through the mount
  errors/         why a write failed
  repositories/   the loaded Iceberg repositories, linked to their checkouts
```

Read, search and edit the code with normal file tools:

```sh
rg "printOn:" <mount>/tonel
```

A write is compiled in the live image and exported back to Tonel. If parsing,
compilation, or blocking critiques fail, the write is rejected and the previous
image state is restored. By default, a write must go to a package of a loaded
Iceberg repository with a checkout, where it can be exported;
[Starting a projection](docs/starting.md) says how to allow the others.

Stop the projection, which unmounts it:

```smalltalk
projection stop
```

## Documentation

- [Starting a projection](docs/starting.md): where it mounts, the
  configuration, which writes it accepts, and the MCP tools.
- [Using the mount](docs/using-the-mount.md): what each directory holds, and
  the code operations a write can make.
- [Projection protocol](docs/protocol.md): how the daemon talks to the image.
- [Agent guide](templates/AGENTS.md): guidance for an agent that edits a
  project through the mount.
