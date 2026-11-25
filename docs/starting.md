# Starting a projection

## Start the projection

Start the Pharo-side projection endpoint and daemon from the image:

```smalltalk
PIFSServer start
```

That mounts at the default mountpoint, under the default volume name, on an
automatically allocated loopback port. The answered projection reports what it
picked:

```smalltalk
projection := PIFSServer start.
projection port.
projection mountPath
```

For a project-specific mountpoint and volume name:

```smalltalk
PIFSServer
	startMountedAt: 'projection' asFileReference
	named: 'pharo-image-fs'
```

Starting answers once the mount is there. A path something is already mounted
at is refused before anything starts. If the daemon exits before mounting, or
the mount has not appeared within the configuration's `mountTimeout` (ten
seconds unless set), starting stops the endpoint and signals an error that
quotes the end of the daemon's log and names the file, which is kept so that
the whole of it can be read. A projection stopped cleanly deletes its daemon's
log and pid file.

Each failure starting foresees is a `PIFSError`, whose `errorCode` names it in
one word, such as `MountPathInUse` or `MountTimedOut`, and whose `details`
hold what a program would otherwise read out of the text, such as the kept log
as `daemonLog`.

Anything else is set through a `PIFSConfiguration`, which carries the
mountpoint, the volume name, the port, how long to wait for the mount, and the
write policy. Only what differs from the default has to be named:

```smalltalk
PIFSServer start: (PIFSConfiguration new
		 mountPath: '/tmp/pharo-image-fs' asFileReference;
		 mountName: 'pharo-image-fs';
		 port: 9013;
		 yourself)
```

A configuration given to `start:` is applied before the mount exists, so the
projection never serves a write under a policy you were about to change.

By default, writes require the target package to belong to a loaded,
file-backed Iceberg repository with an existing source directory. Merely having
an Iceberg repository entry that lists the package is not enough: the projection
must know where to export the changed Tonel source. This keeps filesystem edits
coherent with exported source.

Packages loaded from the image itself, system packages, or repositories without
an attached checkout are rejected in this default mode with a clear repository
ownership error. To allow live-image-only writes, for example in a scratch image,
disable the check on the projection backend:

```smalltalk
PIFSServer start: (PIFSConfiguration new
		 requiresRepositoryOwnershipForWrites: false;
		 yourself)
```

The same switch is reachable on a running projection as
`projection backend requiresRepositoryOwnershipForWrites: false`, which takes
effect on later filesystem operations.

Stop it from Pharo with the projection itself, or by the port it reports:

```smalltalk
projection stop.
PIFSServer stopOn: 9013
```

Use `PIFSServer stopAll` to stop every projection server
started through this API.

The mountpoint path is created when it is missing. If the path already exists,
it must be a directory.

Stopping a projection unmounts it. To unmount one by hand, on macOS:

```sh
umount /tmp/pharo-image-fs
```

On Linux:

```sh
fusermount3 -u /tmp/pharo-image-fs
```

A mount something still uses stays until it is closed; the daemon never
forces an unmount.

## Daemon binary

By default, the Pharo backend downloads the matching daemon release into its
local cache before starting the mount. For local development, set
`PHARO_IMAGE_FS_DAEMON` to a daemon executable path to bypass the download.

## Limit visible packages

By default, `/tonel` exposes every package in the image. A projection can be
limited to package-name prefixes when a large image would make that surface too
broad. Set an inclusion list to expose only matching prefixes, or an exclusion
list to hide matching prefixes. Exclusions take precedence over inclusions.

```smalltalk
PIFSServer start: (PIFSConfiguration new
		 includedPackagePrefixes: #( 'MyProject' );
		 excludedPackagePrefixes: #( 'MyProject-Legacy' );
		 yourself)
```

An empty inclusion list, the default, does not restrict packages. Filtered
packages are treated as absent for listing, reading, writing, deleting,
renaming, and `/critiques`; this avoids exposing a package through one path
while hiding it through another. Update the lists on the running backend to
change what the mount exposes on later filesystem operations.

## Format written methods

A write keeps the source it was given. Pharo formatting is available as an
opt-in that reformats every method a write compiles:

```smalltalk
PIFSServer start: (PIFSConfiguration new formatsWrittenMethods: true; yourself)
```

Set `PHARO_IMAGE_FS_FORMAT` before starting the image to make formatting the
default for every projection in it. `0`, `false`, `no`, `off`, and an empty
value keep it off; any other value turns it on. The configuration overrides the
variable.

Formatting uses the formatter of the package being edited, the one its
manifest answers from a class-side `formatter` method, and the image default
when the package defines none.

## Serve the projection as MCP tools

An image running an MCP server can mount and unmount its projection through
tools rather than through evaluated code. Load the `Tools` group and the catalog
gains `pifs_start`, `pifs_stop` and `pifs_list`:

```smalltalk
Metacello new
	baseline: 'PharoImageFS';
	repository: 'github://Evref-BL/pharo-image-fs:main/src';
	load: 'Tools'
```

The tools are discoverable rather than advertised, so they reach a client
through `tool_search` and `tool_call` without taking room in the tool list
every session starts with.

A call that fails for a reason the tools foresee names that reason in the
`errorCode` of its error details, such as `ProjectionNotFound`, so a program
tells failures apart without reading the text.
